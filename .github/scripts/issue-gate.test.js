'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { MARKER, parseReferences, parseChecklist, touchesCode, evaluate } = require('./issue-gate.js');

const issue = (criteria, deliverables = ['- [x] Thing']) =>
  `### Summary\nx\n\n### Deliverables\n${deliverables.join('\n')}\n\n### Acceptance criteria\n${criteria.join('\n')}\n\n### How to verify\n- [ ] not part of criteria\n`;

const CODE = ['puls3_server/lib/a.dart'];
const REPO = 'Zer0-Knowledge-Hack/puls3';
// GitHub's closingIssuesReferences for the PR, as the workflow injects it.
const cl = (...nums) => nums.map((number) => ({ number, repo: REPO }));

test('all criteria checked: Closes passes', () => {
  const r = evaluate({
    body: 'Closes #1',
    repo: REPO,
    closing: cl(1),
    files: CODE,
    issues: { 1: issue(['- [x] A', '- [X] B']) },
  });
  assert.equal(r.status, 'pass');
  assert.deepEqual(r.failures, []);
});

test('some criteria unchecked: Closes fails and lists them', () => {
  const r = evaluate({
    body: 'Fixes #2',
    repo: REPO,
    closing: cl(2),
    files: CODE,
    issues: { 2: issue(['- [x] A', '- [ ] B missing', '- [ ] C missing']) },
  });
  assert.equal(r.status, 'fail');
  assert.equal(r.failures.length, 1);
  assert.match(r.failures[0], /- \[ \] B missing/);
  assert.match(r.failures[0], /- \[ \] C missing/);
  assert.doesNotMatch(r.failures[0], /\] A$/m);
  assert.match(r.failures[0], /Refs #2/);
});

test('issue without a checklist section: nothing to verify, passes with a notice', () => {
  const r = evaluate({ body: 'Resolves #3', repo: REPO, closing: cl(3), files: CODE, issues: { 3: '### Summary\nNo lists' } });
  assert.equal(r.status, 'pass');
  assert.match(r.notices.join('\n'), /#3 has no "Acceptance criteria"/);
});

test('multiple closed issues: every offender is reported', () => {
  const r = evaluate({
    body: 'Closes #4, closes #5 and Fixes #6',
    repo: REPO,
    closing: cl(4, 5, 6),
    files: CODE,
    issues: {
      4: issue(['- [x] A']),
      5: issue(['- [ ] B5']),
      6: issue(['- [ ] B6']),
    },
  });
  assert.equal(r.status, 'fail');
  assert.equal(r.failures.length, 2);
  assert.match(r.failures[0], /#5/);
  assert.match(r.failures[1], /#6/);
});

test('Refs only: passes and builds one sticky comment with the remaining items', () => {
  const r = evaluate({
    body: 'Refs #7',
    repo: REPO,
    files: CODE,
    issues: { 7: issue(['- [x] A', '- [ ] Left over'], ['- [ ] Deliverable left']) },
  });
  assert.equal(r.status, 'pass');
  assert.ok(r.comment.startsWith(MARKER));
  assert.match(r.comment, /Left over/);
  assert.match(r.comment, /Deliverable left/);
  assert.doesNotMatch(r.comment, /- \[ \] A\b/);
});

test('Refs only with everything checked: no comment', () => {
  const r = evaluate({ body: 'Refs #8', repo: REPO, files: CODE, issues: { 8: issue(['- [x] A']) } });
  assert.equal(r.status, 'pass');
  assert.equal(r.comment, null);
});

test('no reference and code changed: fails', () => {
  const r = evaluate({ body: 'just a change', files: CODE });
  assert.equal(r.status, 'fail');
  assert.match(r.failures[0], /references no issue/);
});

test('no reference and docs-only: passes', () => {
  const r = evaluate({ body: 'typo', files: ['docs/a.md', 'README.md'] });
  assert.equal(r.status, 'pass');
});

test('opt-out label and dependabot skip the gate', () => {
  assert.equal(evaluate({ body: '', labels: ['no-issue'], files: CODE }).status, 'pass');
  assert.equal(evaluate({ body: '', author: 'dependabot[bot]', files: CODE }).status, 'pass');
});

test('other labels do not opt out', () => {
  assert.equal(evaluate({ body: '', labels: ['type: feat'], files: CODE }).status, 'fail');
});

test('parseReferences reads only Refs and ignores HTML comments, code and the placeholder', () => {
  const body = 'Closes #\n<!-- Refs #9 -->\n`Refs #10`\nRefs #11\nCloses #12 Refs #13';
  assert.deepEqual(parseReferences(body, REPO), { refs: [11, 13] });
});

test('parseChecklist stops at the next heading and handles CRLF', () => {
  const body = '### Acceptance criteria\r\n- [x] A\r\n- [ ] B\r\n### Other\r\n- [ ] C\r\n';
  assert.deepEqual(parseChecklist(body, 'Acceptance criteria'), [
    { checked: true, text: 'A' },
    { checked: false, text: 'B' },
  ]);
  assert.equal(parseChecklist(body, 'Deliverables'), null);
});

test('Closes failure tells the author to re-run the job after ticking criteria', () => {
  const r = evaluate({ body: 'Closes #3', repo: REPO, closing: cl(3), files: CODE, issues: { 3: issue(['- [ ] A']) } });
  assert.equal(r.status, 'fail');
  assert.match(r.failures[0], /re-run the `Issue gate \/ issue-gate` job/);
});

test('Closes owner/repo#N for this repo is verified', () => {
  const body = `Closes ${REPO}#12\nRefs #1`;
  const r = evaluate({
    body,
    repo: REPO,
    closing: cl(12),
    files: CODE,
    issues: { 12: issue(['- [ ] A']), 1: issue(['- [x] A']) },
  });
  assert.equal(r.status, 'fail');
  assert.match(r.failures[0], /#12/);
});

test('Refs owner/repo#N prefix match is case-insensitive', () => {
  assert.deepEqual(parseReferences('Refs zer0-knowledge-hack/PULS3#5', REPO).refs, [5]);
  assert.deepEqual(parseReferences('Refs other/repo#5', REPO).refs, []);
});

test('Closes in another repository fails: the gate cannot verify it', () => {
  const r = evaluate({
    body: 'Closes other/repo#9\nRefs #1',
    repo: REPO,
    closing: [{ number: 9, repo: 'other/repo' }],
    files: CODE,
    issues: { 1: issue(['- [x] A']) },
  });
  assert.equal(r.status, 'fail');
  assert.match(r.failures.join('\n'), /other\/repo#9/);
});

test('a heading nested under the section does not end it', () => {
  const body = '### Acceptance criteria\n- [x] a\n#### Backend\n- [ ] b\n### Other\n- [ ] c\n';
  assert.deepEqual(parseChecklist(body, 'Acceptance criteria'), [
    { checked: true, text: 'a' },
    { checked: false, text: 'b' },
  ]);
  const r = evaluate({ body: 'Closes #1', repo: REPO, closing: cl(1), files: CODE, issues: { 1: body } });
  assert.equal(r.status, 'fail');
});

test('a higher-level heading ends the section', () => {
  const body = '### Acceptance criteria\n- [x] a\n## Next\n- [ ] z\n';
  assert.deepEqual(parseChecklist(body, 'Acceptance criteria'), [{ checked: true, text: 'a' }]);
});

test('a # line inside a code fence neither ends the section nor yields items', () => {
  const body = '### Acceptance criteria\n- [x] a\n```sh\n# comment\n- [ ] fake\n```\n- [ ] b\n';
  assert.deepEqual(parseChecklist(body, 'Acceptance criteria'), [
    { checked: true, text: 'a' },
    { checked: false, text: 'b' },
  ]);
});

test('heading with a trailing colon is still found', () => {
  assert.deepEqual(parseChecklist('### Acceptance criteria:\n- [ ] a\n', 'Acceptance criteria'), [
    { checked: false, text: 'a' },
  ]);
});

test('numbered checklist items are read', () => {
  const body = '### Acceptance criteria\n1. [x] a\n2) [ ] b\n';
  assert.deepEqual(parseChecklist(body, 'Acceptance criteria'), [
    { checked: true, text: 'a' },
    { checked: false, text: 'b' },
  ]);
});

test('Closes pointing at a PR or a missing issue counts as referencing no issue', () => {
  for (const issues of [{ 5: null }, {}]) {
    const r = evaluate({ body: 'Closes #5', repo: REPO, closing: cl(5), files: CODE, issues });
    assert.equal(r.status, 'fail');
    assert.match(r.failures[0], /references no issue/);
  }
  const docs = evaluate({ body: 'Refs #5', repo: REPO, files: ['README.md'], issues: { 5: null } });
  assert.equal(docs.status, 'pass');
});

test('Closes with one unresolved and one valid issue still verifies the valid one', () => {
  const r = evaluate({ body: 'Closes #5, closes #6', repo: REPO, closing: cl(5, 6), files: CODE, issues: { 5: null, 6: issue(['- [x] A']) } });
  assert.equal(r.status, 'pass');
});

test('.txt files are not docs-only', () => {
  assert.equal(touchesCode(['requirements.txt']), true);
  assert.equal(touchesCode(['README.md', 'docs/a.png']), false);
});

test('Closes with the URL form is caught through closingIssuesReferences', () => {
  const r = evaluate({
    body: `Closes https://github.com/${REPO}/issues/5\nRefs #6`,
    repo: REPO,
    closing: cl(5),
    files: CODE,
    issues: { 5: issue(['- [ ] Unmet']), 6: issue(['- [x] A']) },
  });
  assert.equal(r.status, 'fail');
  assert.match(r.failures[0], /closes #5/);
  assert.match(r.failures[0], /Unmet/);
});

test('an issue linked only in the Development sidebar is verified', () => {
  const r = evaluate({ body: 'no keyword here', repo: REPO, closing: cl(8), files: CODE, issues: { 8: issue(['- [ ] Unmet']) } });
  assert.equal(r.status, 'fail');
  assert.match(r.failures[0], /closes #8/);
});

test('a Closes keyword GitHub does not act on is not treated as closing', () => {
  const r = evaluate({ body: 'Closes #5\nRefs #6', repo: REPO, closing: [], files: CODE, issues: { 5: issue(['- [ ] Unmet']), 6: issue(['- [x] A']) } });
  assert.equal(r.status, 'pass');
});

test('an issue both closed and referenced counts as closed', () => {
  const r = evaluate({ body: 'Refs #5', repo: REPO, closing: cl(5), files: CODE, issues: { 5: issue(['- [ ] Unmet']) } });
  assert.equal(r.status, 'fail');
  assert.equal(r.comment, null);
});

test('checkboxes inside HTML comments are not criteria', () => {
  const body = '### Acceptance criteria\n- [x] real\n<!-- - [ ] template hint -->\n<!--\n- [ ] multi\n-->\n- [x] also real\n';
  assert.deepEqual(parseChecklist(body, 'Acceptance criteria'), [
    { checked: true, text: 'real' },
    { checked: true, text: 'also real' },
  ]);
});

test('a path that only starts with ISSUE_TEMPLATE is not docs-only', () => {
  assert.equal(touchesCode(['.github/ISSUE_TEMPLATE_x/run.js']), true);
  assert.equal(touchesCode(['.github/ISSUE_TEMPLATE/bug.yml']), false);
});

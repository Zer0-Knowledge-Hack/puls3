'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { MARKER, parseReferences, parseChecklist, touchesCode, evaluate } = require('./issue-gate.js');

const issue = (criteria, deliverables = ['- [x] Thing']) =>
  `### Summary\nx\n\n### Deliverables\n${deliverables.join('\n')}\n\n### Acceptance criteria\n${criteria.join('\n')}\n\n### How to verify\n- [ ] not part of criteria\n`;

const CODE = ['puls3_server/lib/a.dart'];

test('all criteria checked: Closes passes', () => {
  const r = evaluate({
    body: 'Closes #1',
    files: CODE,
    issues: { 1: issue(['- [x] A', '- [X] B']) },
  });
  assert.equal(r.status, 'pass');
  assert.deepEqual(r.failures, []);
});

test('some criteria unchecked: Closes fails and lists them', () => {
  const r = evaluate({
    body: 'Fixes #2',
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
  const r = evaluate({ body: 'Resolves #3', files: CODE, issues: { 3: '### Summary\nNo lists' } });
  assert.equal(r.status, 'pass');
  assert.match(r.notices.join('\n'), /#3 has no "Acceptance criteria"/);
});

test('multiple closed issues: every offender is reported', () => {
  const r = evaluate({
    body: 'Closes #4, closes #5 and Fixes #6',
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
  const r = evaluate({ body: 'Refs #8', files: CODE, issues: { 8: issue(['- [x] A']) } });
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

test('parseReferences ignores HTML comments, code and the template placeholder', () => {
  const body = 'Closes #\n<!-- Use "Closes #9" only if ... -->\n`Closes #10`\nRefs #11\nCloses #12 Refs #12';
  assert.deepEqual(parseReferences(body), { closes: [12], refs: [11], foreign: [] });
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
  const r = evaluate({ body: 'Closes #3', files: CODE, issues: { 3: issue(['- [ ] A']) } });
  assert.equal(r.status, 'fail');
  assert.match(r.failures[0], /re-run the `Issue gate \/ gate` job/);
});

const REPO = 'Zer0-Knowledge-Hack/puls3';

test('Closes owner/repo#N for this repo is parsed and verified', () => {
  const body = `Closes ${REPO}#12\nRefs #1`;
  assert.deepEqual(parseReferences(body, REPO).closes, [12]);
  const r = evaluate({
    body,
    repo: REPO,
    files: CODE,
    issues: { 12: issue(['- [ ] A']), 1: issue(['- [x] A']) },
  });
  assert.equal(r.status, 'fail');
  assert.match(r.failures[0], /#12/);
});

test('owner/repo prefix match is case-insensitive', () => {
  assert.deepEqual(parseReferences('Closes zer0-knowledge-hack/PULS3#5', REPO).closes, [5]);
});

test('Closes in another repository fails: the gate cannot verify it', () => {
  const r = evaluate({
    body: 'Closes other/repo#9\nRefs #1',
    repo: REPO,
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
  const r = evaluate({ body: 'Closes #1', files: CODE, issues: { 1: body } });
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
    const r = evaluate({ body: 'Closes #5', files: CODE, issues });
    assert.equal(r.status, 'fail');
    assert.match(r.failures[0], /references no issue/);
  }
  const docs = evaluate({ body: 'Refs #5', files: ['README.md'], issues: { 5: null } });
  assert.equal(docs.status, 'pass');
});

test('Closes with one unresolved and one valid issue still verifies the valid one', () => {
  const r = evaluate({ body: 'Closes #5, closes #6', files: CODE, issues: { 5: null, 6: issue(['- [x] A']) } });
  assert.equal(r.status, 'pass');
});

test('.txt files are not docs-only', () => {
  assert.equal(touchesCode(['requirements.txt']), true);
  assert.equal(touchesCode(['README.md', 'docs/a.png']), false);
});

'use strict';

// Issue deliverables gate (see CONTRIBUTING.md, "Closes vs Refs").
// Pure functions only: the workflow fetches data from GitHub and passes it in,
// so everything here is unit-testable offline. Node 20+, no dependencies.

const MARKER = '<!-- issue-deliverables-gate -->';
const RERUN_HINT =
  'Editing an issue does not trigger this check: after ticking criteria, re-run the ' +
  '`Issue gate / gate` job (Actions tab, "Re-run jobs") or edit the PR description.';

const OPT_OUT_LABEL = 'no-issue';
const CLOSING = '(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)';
// An optional `owner/repo` prefix is captured: GitHub closes `owner/repo#N` too.
const ISSUE_REF = '([\\w.-]+/[\\w.-]+)?#(\\d+)\\b';
const CLOSES_RE = new RegExp(`(?<![\\w-])${CLOSING}:?\\s+${ISSUE_REF}`, 'gi');
const REFS_RE = new RegExp(`(?<![\\w-])(?:refs?|related to|part of):?\\s+${ISSUE_REF}`, 'gi');

// Paths that never need an issue on their own.
const DOCS_RE = /(^|\/)(LICENSE|CODEOWNERS)$|\.(md|mdx|png|jpe?g|gif|svg)$|^docs\/|^\.github\/(ISSUE_TEMPLATE|pull_request_template\.md)/i;

function stripNoise(text) {
  return String(text || '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`\n]*`/g, '');
}

// Splits matches into this repo's issue numbers and other-repo references.
// A prefix naming another repo (or any prefix when `repo` is unknown) is foreign.
function collect(re, text, repo) {
  const local = [];
  const foreign = [];
  for (const m of text.matchAll(re)) {
    if (m[1] && (!repo || m[1].toLowerCase() !== repo.toLowerCase())) {
      foreign.push(`${m[1]}#${m[2]}`);
    } else {
      local.push(Number(m[2]));
    }
  }
  return { local, foreign };
}

function unique(list) {
  return [...new Set(list)];
}

// A number that is both closed and referenced counts as closed.
// `repo` is "owner/name" of the PR's repository; `foreign` lists closing
// references to other repositories, which the gate cannot verify.
function parseReferences(body, repo) {
  const text = stripNoise(body);
  const c = collect(CLOSES_RE, text, repo);
  const closes = unique(c.local);
  const refs = unique(collect(REFS_RE, text, repo).local).filter((n) => !closes.includes(n));
  return { closes, refs, foreign: unique(c.foreign) };
}

// Returns the checkbox items under the heading named `heading`, or null when
// the section does not exist or has no checkboxes. The section ends at the next
// heading of the same or a higher level (sub-headings stay inside it); fenced
// code blocks are skipped, so a `#` line or a checkbox inside one is ignored.
function parseChecklist(issueBody, heading) {
  const lines = String(issueBody || '').replace(/\r\n?/g, '\n').split('\n');
  const want = heading.trim().toLowerCase();
  let inside = false;
  let level = 0;
  let found = false;
  let fence = null;
  const items = [];
  for (const line of lines) {
    const f = /^\s*(`{3,}|~{3,})/.exec(line);
    if (fence) {
      if (f && f[1][0] === fence[0] && f[1].length >= fence.length) fence = null;
      continue;
    }
    if (f) {
      fence = f[1];
      continue;
    }
    const h = /^(#{1,6})\s+(.*?)\s*#*\s*$/.exec(line);
    if (h) {
      const name = h[2].trim().replace(/:$/, '').trim().toLowerCase();
      if (name === want && (!inside || h[1].length <= level)) {
        inside = true;
        level = h[1].length;
        found = true;
      } else if (inside && h[1].length <= level) {
        inside = false;
      }
      continue;
    }
    if (!inside) continue;
    const c = /^\s*(?:[-*+]|\d+[.)])\s+\[([ xX])\]\s+(.*\S)\s*$/.exec(line);
    if (c) items.push({ checked: c[1] !== ' ', text: c[2] });
  }
  return found && items.length > 0 ? items : null;
}

function readIssue(issueBody) {
  return {
    deliverables: parseChecklist(issueBody, 'Deliverables'),
    criteria: parseChecklist(issueBody, 'Acceptance criteria'),
  };
}

const unchecked = (items) => (items || []).filter((i) => !i.checked);

function touchesCode(files) {
  return (files || []).some((f) => !DOCS_RE.test(f));
}

function bullets(items) {
  return items.map((i) => `- [ ] ${i.text}`).join('\n');
}

// input: { body, labels: string[], author, files: string[],
//          issues: { [number]: string | null } }  (null = not found / not an issue)
// output: { status: 'pass' | 'fail', failures: string[], notices: string[],
//           comment: string | null }
function evaluate({ body, repo, labels = [], author = '', files = [], issues = {} }) {
  const out = { status: 'pass', failures: [], notices: [], comment: null };
  if (/^dependabot(\[bot\])?$/i.test(author)) {
    out.notices.push('Skipped: Dependabot pull request.');
    return out;
  }
  if (labels.includes(OPT_OUT_LABEL)) {
    out.notices.push(`Skipped: the \`${OPT_OUT_LABEL}\` label is set.`);
    return out;
  }

  const { closes, refs, foreign } = parseReferences(body, repo);

  for (const f of foreign) {
    out.failures.push(
      `This pull request closes \`${f}\` in another repository, which this gate cannot ` +
        `verify. Use \`Refs\` for it, or ask a maintainer to add the \`${OPT_OUT_LABEL}\` label.`,
    );
  }

  // A reference only counts when it resolves to a real issue in this repo
  // (not a PR number, not a missing or deleted issue).
  const resolved = [...closes, ...refs].filter((n) => issues[n] != null);
  if (resolved.length === 0 && foreign.length === 0) {
    if (touchesCode(files)) {
      out.failures.push(
        'This pull request changes code but references no issue (a reference to a pull ' +
          'request or to a missing issue does not count). Add `Closes #N` ' +
          '(every acceptance criterion met) or `Refs #N` (partial work) to the ' +
          `description, or ask a maintainer to add the \`${OPT_OUT_LABEL}\` label.`,
      );
    } else {
      out.notices.push('No issue referenced; the change is docs-only, so none is required.');
    }
  }

  for (const n of closes) {
    if (issues[n] == null) {
      out.notices.push(`#${n} was not found as an issue; nothing to verify.`);
      continue;
    }
    const { criteria } = readIssue(issues[n]);
    if (!criteria) {
      out.notices.push(`#${n} has no "Acceptance criteria" checklist; nothing to verify.`);
      continue;
    }
    const open = unchecked(criteria);
    if (open.length > 0) {
      out.failures.push(
        `This pull request closes #${n}, but ${open.length} acceptance criteri` +
          `${open.length === 1 ? 'on is' : 'a are'} not checked in the issue:\n${bullets(open)}\n` +
          `Tick them in the issue with evidence, or change \`Closes #${n}\` to ` +
          `\`Refs #${n}\` for partial work. ${RERUN_HINT}`,
      );
    }
  }

  const sections = [];
  for (const n of refs) {
    if (issues[n] == null) {
      out.notices.push(`#${n} was not found as an issue; nothing to report.`);
      continue;
    }
    const { criteria, deliverables } = readIssue(issues[n]);
    const openCriteria = unchecked(criteria);
    const openDeliverables = unchecked(deliverables);
    if (openCriteria.length === 0 && openDeliverables.length === 0) continue;
    let s = `#### Remaining on #${n}\n`;
    if (openCriteria.length) s += `\n**Acceptance criteria**\n${bullets(openCriteria)}\n`;
    if (openDeliverables.length) s += `\n**Deliverables**\n${bullets(openDeliverables)}\n`;
    sections.push(s);
  }
  if (sections.length > 0) {
    out.comment =
      `${MARKER}\n### Partial work: remaining items\n\n` +
      'This pull request uses `Refs`, so it does not close the issue(s) below. ' +
      'These items are still unchecked:\n\n' +
      `${sections.join('\n')}\n` +
      'Use `Closes #N` only once every acceptance criterion is checked.';
  }

  if (out.failures.length > 0) out.status = 'fail';
  return out;
}

module.exports = {
  MARKER,
  OPT_OUT_LABEL,
  parseReferences,
  parseChecklist,
  touchesCode,
  evaluate,
};

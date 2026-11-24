'use strict';

// Issue deliverables gate (see CONTRIBUTING.md, "Closes vs Refs").
// Pure functions only: the workflow fetches data from GitHub and passes it in,
// so everything here is unit-testable offline. Node 20+, no dependencies.

const MARKER = '<!-- issue-deliverables-gate -->';
const OPT_OUT_LABEL = 'no-issue';
const CLOSING = '(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)';
const CLOSES_RE = new RegExp(`(?<![\\w-])${CLOSING}:?\\s+#(\\d+)\\b`, 'gi');
const REFS_RE = /(?<![\w-])(?:refs?|related to|part of):?\s+#(\d+)\b/gi;

// Paths that never need an issue on their own.
const DOCS_RE = /(^|\/)(LICENSE|CODEOWNERS)$|\.(md|mdx|txt|png|jpe?g|gif|svg)$|^docs\/|^\.github\/(ISSUE_TEMPLATE|pull_request_template\.md)/i;

function stripNoise(text) {
  return String(text || '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`\n]*`/g, '');
}

function collect(re, text) {
  const found = [];
  for (const m of text.matchAll(re)) found.push(Number(m[1]));
  return found;
}

function unique(list) {
  return [...new Set(list)];
}

// A number that is both closed and referenced counts as closed.
function parseReferences(body) {
  const text = stripNoise(body);
  const closes = unique(collect(CLOSES_RE, text));
  const refs = unique(collect(REFS_RE, text)).filter((n) => !closes.includes(n));
  return { closes, refs };
}

// Returns the checkbox items under `### <heading>` (until the next heading),
// or null when the section does not exist or has no checkboxes.
function parseChecklist(issueBody, heading) {
  const lines = String(issueBody || '').replace(/\r\n?/g, '\n').split('\n');
  const want = heading.trim().toLowerCase();
  let inside = false;
  let found = false;
  const items = [];
  for (const line of lines) {
    const h = /^#{1,6}\s+(.*?)\s*#*\s*$/.exec(line);
    if (h) {
      inside = h[1].trim().toLowerCase() === want;
      found = found || inside;
      continue;
    }
    if (!inside) continue;
    const c = /^\s*[-*+]\s+\[([ xX])\]\s+(.*\S)\s*$/.exec(line);
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
function evaluate({ body, labels = [], author = '', files = [], issues = {} }) {
  const out = { status: 'pass', failures: [], notices: [], comment: null };
  if (/^dependabot(\[bot\])?$/i.test(author)) {
    out.notices.push('Skipped: Dependabot pull request.');
    return out;
  }
  if (labels.includes(OPT_OUT_LABEL)) {
    out.notices.push(`Skipped: the \`${OPT_OUT_LABEL}\` label is set.`);
    return out;
  }

  const { closes, refs } = parseReferences(body);

  if (closes.length === 0 && refs.length === 0) {
    if (touchesCode(files)) {
      out.failures.push(
        'This pull request changes code but references no issue. Add `Closes #N` ' +
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
          `\`Refs #${n}\` for partial work.`,
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

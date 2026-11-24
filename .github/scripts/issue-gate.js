'use strict';

// Issue deliverables gate (see CONTRIBUTING.md, "Closes vs Refs").
// Pure functions only: the workflow fetches data from GitHub and passes it in,
// so everything here is unit-testable offline. Node 20+, no dependencies.

const MARKER = '<!-- issue-deliverables-gate -->';
const RERUN_HINT =
  'Editing an issue does not trigger this check: after ticking criteria, re-run the ' +
  '`Issue gate / issue-gate` job (Actions tab, "Re-run jobs") or edit the PR description.';

const OPT_OUT_LABEL = 'no-issue';
// Which issues a PR closes is NOT parsed from the body: the workflow reads GitHub's own
// `closingIssuesReferences` (keyword forms, URL forms and Development-sidebar links) and
// passes it to evaluate() as `closing`. Only `Refs` is read from the body.
// An optional `owner/repo` prefix is captured.
const ISSUE_REF = '([\\w.-]+/[\\w.-]+)?#(\\d+)\\b';
const REFS_RE = new RegExp(`(?<![\\w-])(?:refs?|related to|part of):?\\s+${ISSUE_REF}`, 'gi');

// Paths that never need an issue on their own.
const DOCS_RE = /(^|\/)(LICENSE|CODEOWNERS)$|\.(md|mdx|png|jpe?g|gif|svg)$|^docs\/|^\.github\/(ISSUE_TEMPLATE\/|pull_request_template\.md$)/i;

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

// Reads the `Refs` references of this repo from the PR body. `repo` is "owner/name".
function parseReferences(body, repo) {
  const text = stripNoise(body);
  return { refs: unique(collect(REFS_RE, text, repo).local) };
}

// Splits GitHub's closing-issue list ([{ number, repo: "owner/name" }]) into this
// repo's issue numbers and foreign references ("owner/name#N"), which the gate
// cannot verify. An entry without a known repo on either side counts as foreign.
function splitClosing(closing, repo) {
  const closes = [];
  const foreign = [];
  for (const c of closing || []) {
    if (c.repo && repo && c.repo.toLowerCase() === repo.toLowerCase()) closes.push(Number(c.number));
    else foreign.push(`${c.repo || '?'}#${c.number}`);
  }
  return { closes: unique(closes), foreign: unique(foreign) };
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
  let inComment = false;
  const items = [];
  for (const raw of lines) {
    let line = raw;
    // HTML comments (single or multi-line) are invisible when rendered: skip them.
    // Fenced code is checked first so a literal `<!--` inside a fence is left alone.
    if (!fence) {
      if (inComment) {
        const end = line.indexOf('-->');
        if (end === -1) continue;
        inComment = false;
        line = line.slice(end + 3);
      }
      line = line.replace(/<!--.*?-->/g, '');
      const open = line.indexOf('<!--');
      if (open !== -1) {
        inComment = true;
        line = line.slice(0, open);
      }
    }
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

// input: { body, repo, labels: string[], author, files: string[],
//          closing: [{ number, repo }]   (GitHub's closingIssuesReferences),
//          issues: { [number]: string | null } }  (null = not found / not an issue)
// output: { status: 'pass' | 'fail', failures: string[], notices: string[],
//           comment: string | null }
function evaluate({ body, repo, labels = [], author = '', files = [], issues = {}, closing = [] }) {
  const out = { status: 'pass', failures: [], notices: [], comment: null };
  if (/^dependabot(\[bot\])?$/i.test(author)) {
    out.notices.push('Skipped: Dependabot pull request.');
    return out;
  }
  if (labels.includes(OPT_OUT_LABEL)) {
    out.notices.push(`Skipped: the \`${OPT_OUT_LABEL}\` label is set.`);
    return out;
  }

  const { closes, foreign } = splitClosing(closing, repo);
  const refs = parseReferences(body, repo).refs.filter((n) => !closes.includes(n));

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

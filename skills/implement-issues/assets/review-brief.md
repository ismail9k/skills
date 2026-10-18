You are reviewing one pull request, unattended and read-only. No one will
answer your questions, and you can't write: no file, no commit, no push, no
comment.

Run `review-prs #<number>` on `<owner/repo>` in its report-only mode:

Report-only: yes
Context: <context dir>
Working directory: <worktree> — the pull request's head is checked out here
Code pass: <code pass: on|off> — off means the build's whole-branch review
already covered the code; say so in the review body
PR code reviewer model: <PR code reviewer model> — use it for the code pass
when it is on

End your reply with exactly one fenced `json` block: the review `review-prs`
would have posted. List the findings you dropped, and why, after it.

# Gerrit disclosure comments (the human posts them, patch set level)

Fill the placeholders and drop lines that do not apply.

## As author

```
AI-assisted contribution: prepared with {tool, e.g. Claude Code} under my supervision.
{With git-ai: ~{N} % of the added lines in patch set {PS} were AI-authored (git-ai stats).}
{If AI code was pasted from another session, git-ai cannot see it: "The fix was AI-generated
and pasted in; git-ai attribution does not cover it."}
I reviewed every line of the diff, ran {suites, e.g. cglGit, phpstan, unit, functional}
locally and take responsibility for this change.
```

## As author, when the human wrote the code and the AI tested/committed

```
Code written by me; {tool} added {tests / QA runs / commit message} under my supervision.
I reviewed the complete diff and take responsibility for this change.
```

## As reviewer

```
AI-assisted review: findings and test runs prepared with {tool} under my supervision;
I verified the findings and the test results myself.
```

# Lab 15 — Remove Large Files from Git History

Rewrite a Git repository to remove large objects using `git filter-repo`, then force-push the cleaned history.

> This is destructive to history. Notify contributors to rebase on the rewritten branches. Never push until you’re sure you removed only the intended files.

## Prerequisites

- Ubuntu 20.04 host
- Git installed
- `git-filter-repo` installed (https://github.com/newren/git-filter-repo)

## Steps

1) Create a test repo with a large file
```bash
mkdir git-test && cd git-test
git init
echo "Init setup" > file1
git add file1 && git commit -m "Version 1"
curl -L https://www.kernel.org/pub/software/scm/git/git-2.1.0.tar.gz > git.tgz
git add git.tgz && git commit -m "Add git tarball"
```

2) Remove the large file in the working tree
```bash
git rm git.tgz
git commit -m "Remove large tarball"
git gc
```

3) Find the large object (optional inspection)
```bash
git verify-pack -v .git/objects/pack/*.idx | sort -k 3 -n | tail -3
git rev-list --objects --all | grep <BLOB_SHA>
```

4) Rewrite history to drop the file
```bash
cd ..
git clone git-test git-test-clean
cd git-test-clean
git filter-repo --invert-paths --path git.tgz
git gc
```

5) Force-push the cleaned history (when using a remote)
```bash
git push origin --force --all
```

## Validation

- `du -sh` shows reduced repo size.
- `git log --stat` no longer contains the removed file.

## Cleanup

```bash
rm -rf git-test git-test-clean
```

## Troubleshooting

- **Missing filter tool**: Install `git-filter-repo` from the link above.
- **Accidental file removal**: Abort and reclone from the original remote before pushing.

## References

- https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository
- https://git-scm.com/book/en/v2/Git-Internals-Maintenance-and-Data-Recovery

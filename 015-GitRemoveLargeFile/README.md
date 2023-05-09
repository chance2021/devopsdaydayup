# Project Name: Remove Large File from Git Commit History

## Project Goal
This lab specifically focuses on the process of removing large file objects from the Git history. **Be warned: this technique is destructive to your commit history.** You have to notify all contributors that they must rebase their work onto your new commits.

## Table of Contents
- [Project Name: Remove Large File from Git Commit History](#project-name-remove-large-file-from-git-commit-history)
  - [Project Goal](#project-goal)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Project Steps](#project-steps)
    - [1. **Initiate** the test environment](#1-initiate-the-test-environment)
    - [2. **Remove** the Large File](#2-remove-the-large-file)
    - [3. Clean the Database](#3-clean-the-database)
    - [4. **Find** Out the Location of The Large File in packfiles](#4-find-out-the-location-of-the-large-file-in-packfiles)
    - [5. **Remove** the File from History](#5-remove-the-file-from-history)
  - [Post Project](#post-project)
  - [Troubleshooting](#troubleshooting)
  - [Reference](#reference)

## <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) 


## <a name="project_steps">Project Steps</a>

### 1. **Initiate** the test environment
Run below command to initiate a git repo
```
mkdir git-test
cd git-test
git init
echo "Init setup" > file1
git add file1
git commit -m "Version 1"
du -sh ./

curl -L https://www.kernel.org/pub/software/scm/git/git-2.1.0.tar.gz > git.tgz
du -sh ./

git add git.tgz
git commit -m 'Add git tarball'
du -sh ./
```

### 2. **Remove** the Large File
```
git rm git.tgz
git commit -m "Remove large tarball"
du -sh ./
```

### 3. Clean the Database
```
git gc
du -sh
git count-objects -v
```

### 4. **Find** Out the Location of The Large File in packfiles
You can find the SHA for the largest file in packfile
```
git verify-pack -v .git/objects/pack/<index name>.idx | sort -k 3 -n | tail -3
```
Note: Please replace **<index name>** with actual index name under `.git/objects/pack` folder. <br/>

Run below command to find out what the file name of the blob:
```
git rev-list --objects --all|grep 82c99a3
```
Note: `82c99a3` is the SHA you found in previous command. It may be different in your scenario.

### 5. **Remove** the File from History
We are going to use `git-filter-repo` command to rewrite the git history. This doesn't come with the original setup and you have to install it seperately. You can follow [this document](https://github.com/newren/git-filter-repo/blob/main/INSTALL.md) to download the tool. <br/>

Since the tool has to be used in a repo which has clean clone, you may need to below step to clone it to another repo in order to use it:
```
cd ..
git clone git-test git-test-new
```
Then run below command to remove the file from the git history
```
cd git-test-new
git filter-repo --invert-paths --path git.tgz
git gc
```
Then you should be able to see the size is reduced
```
du -sh
git count-objects -v
```
Last, you can push the change to the remote repo to finish this lab
```
git push origin --force --all
```

## <a name="post_project">Post Project</a>
Just remove the repo folders
```
rm -rf git-test git-test-new
```

## <a name="troubleshooting">Troubleshooting</a>

## <a name="reference">Reference</a>
- [Git Pro - Git 内部原理之维护与数据恢复](https://git-scm.com/book/zh/v2/Git-%E5%86%85%E9%83%A8%E5%8E%9F%E7%90%86-%E7%BB%B4%E6%8A%A4%E4%B8%8E%E6%95%B0%E6%8D%AE%E6%81%A2%E5%A4%8D)
- [Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
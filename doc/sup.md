---
title:  Sup
date:   Version 0.6.9, 2020-09-06
---


Overview
========

Sup is the file **sup**plement tool.  It provides a simple way to keep binary
files in sync with a code repository while maintaining a clear separation
between the management of the supplemental files and the code.
It's a light-weight alternative to systems like *Git LFS* or *git-annex*,
though it can be used with other version control software, or even none at all.

Sup is a [Boron] script which uses *rsync* and *curl* to do the heavy
lifting of file transfers and synchronization.
The script can be found in the [Boron Library].

An additional [sup-git] script can be used for a bit more integration with Git.

> **_WARNING:_** The software is currently in beta so back up your files!

File transfer is currently limited to rsync (local or via SSH) and HTTP.


Installation
============

The scripts can be downloaded directly to your `~/bin` with these commands:

    curl -s -L https://tinyurl.com/boron-library-sup -o ~/bin/sup
    curl -s -L https://tinyurl.com/sup-git -o ~/bin/sup-git
    chmod +x ~/bin/sup ~/bin/sup-git

If you download via another method make sure to rename or link the scripts
without the `.b` filename extension.


Repository Mode
===============

Supplements can be initialized to either **_repository_** or **_lean_** mode.

In *repository* mode the .supplement/ directory stores all versions
of all files added to it.

In *lean* mode pulling from an HTTP remote will only populate the working
directory.  This is basically a read-only copy of a remote which can be used
if disk space needs to be conserved.

Note that in the current version use of a rsync remote always acts as if
*repository* mode is enabled.  The mode only affects how the [pull] & [reset]
actions operate on HTTP remotes; other actions such as [add] will still copy
files into .supplement/.

To change the mode after [init] is done you must manually edit the
`repository` value in .supplement/config to be either `true` or `false`.


Actions
=======

Running `sup` without arguments will show the usage and available actions.

    Usage: sup <action>

    Actions:
      add <files>           Add files to supplement and index.
      help                  Print usage.
      import                Copy git-annex files into a new supplement.
      init [-r]             Create new local supplement repository.
      move <from> <to>      Change file path in working directory and index.
      prune                 Remove all supplement files not in the current index.
      pull [<remote>] [-i]  Transfer files from remote to local supplement.
      push [<remote>]       Transfer files from local to remote supplement.
      remove <files>        Remove files from the index and working directory.
      reset [<files>] [-r <remote>]
                            Restore working files from index.
      source <name> <url>   Define remote supplement to fetch files from.
      verify                Show working files which do not match the index.

To create a new supplement use the [init] action then [add] your files:

    sup init -r
    sup add my-images/*.png

To define a remote supplement and upload the files use [source] and [push]:

    sup source sfnet $USER@web.sf.net:/home/project-web/projectx/htdocs/my-supplement
    sup push

## Add
Add files to the supplement and index.

## Help
Help simply prints the usage.

## Import
Import copies git-annex files into a new supplement repository.
This works by finding the `.git/annex` symbolic links, so the annex files
should all be locked.

    git annex lock
    sup import

Removal of the annex is left as an exercise for the user.

## Init
Init creates a new supplement in the current directory.

The `-r` option sets the configuration to [repository mode].

## Move
Rename a single file and update its path in the index.

## Prune
> **_NOTE:_** This is not yet implemented!

Remove all supplement files not in the current index.

## Pull
Pull transfers files from a remote to the local supplement.
If no remote name is specified then the first one defined in the
.supplement/config will be used.

Use the `-i` option to also fetch the remote index.  This should not be used if
the .supplement/index is being tracked in your version control software or
else it will be changed.

If [repository mode] is not enabled then a pull from an HTTP remote will only
copy those files listed in the index into the working directory.

## Push
Transfer files from the local supplement to a rsync remote.
If no remote name is specified then the first one defined in the
.supplement/config will be used.

This will not work with HTTP remotes.

## Remove
Remove files from the index and working directory.  The files are not removed
from the supplement repository.

Sup will return an exit status of 1 if any specified file is not present
in the index.

## Reset
Restore working files to those listed in the index.  If no files are specified
then all changed files are restored.

If [repository mode] is not enabled then any modified files must be
downloaded from an HTTP remote.  The optional remote name can be specified in
this case.

## Source
Define a remote supplement to fetch files from.

The remote name is an identifier to be used with actions such as [push] &
[pull].
The name is restricted to ASCII letter, digit, underscore and dash characters.
It must begin with a letter.

The URL argument determines the remote type using these rules:

  @. An HTTP remote begins with "http".
  @. A local rsync directory begins with "/".
  @. Otherwise the URL is assumed to be a SSH server for rsync use.

This example will work for SourceForge project-web servers:

    sup source sfnet $USER,$PROJECT@web.sourceforge.net:/home/project-web/$PROJECT/htdocs/my-supplement


## Verify
Verify shows working files which do not match the index.  This can be used to
see what files need to be added and would be overwritten by [reset].

Sup will return an exit status of 1 if any files have changed.


Use with Git
============

After initializing the supplement begin tracking the index with `git`.

    git add .supplement/index
    git commit

Then, when binary files change add them to the supplement and commit the index.

    sup add $FILE1 $FILE2
    git add .supplement/index
    git commit

When changes are pushed to a Git remote it is likely you will also want to
update a supplement remote.

    git push origin master
    sup push

After checking out a new commit the [reset] action will make sure the files
in the current supplement index are copied to the working directory.

    git checkout $MY_BRANCH
    sup reset

The following lines can be added to the `.gitignore` file for a clean
`git status`:

    /.supplement/*
    !/.supplement/index


## Git Integration

The [sup-git] script can be used with Git checkout & merge hooks to keep the
working directory synchronized with the supplement index.  Note that this will
require the supplement to be in [repository mode].

Using `sup-git install` creates the hooks and will also add the `.gitignore`
lines mentioned above.  The hooks will then call `sup-git` as needed.

To remove these changes the following files must be manually edited:

    .git/hooks/post-checkout
    .git/hooks/post-merge
    .gitignore


<!--
Implementation
==============
-->


Notes on git-annex
==================

Sup was written as a replacement for *git-annex* after having used that for a
number of months.  The two main problems are:

  * Having to unlock files for editing is a hassle.
  * The invasive nature of the extension is messy.  It uses branches for
    configuration and modifies the normal git behavior.

Other issues which made using it less than pleasant include:

  * Even after many years of development the usage semantics are not stable
    (see [git-annex add]).
  * As of version 7 basic functionality such as hosting files on a web server
    is not possible without an associated Git repository
    (see [git-annex web]).
  * Setting it up to fetch from an rsync remote is difficult and fails with
    vague errors.


Support
=======

If you have any questions or issues you can email
wickedsmoke [at] users.sf.net.


[Boron]: http://urlan.sourceforge.net/boron/
[Boron Library]: https://sourceforge.net/p/urlan/boron/library/ci/master/tree/filesystem/sup.b
[sup-git]: https://sourceforge.net/p/urlan/boron/library/ci/master/tree/filesystem/sup-git.b
[git-annex add]: https://git-annex.branchable.com/forum/__34__git_add__34___vs___34__git_annex_add__34___in_v6/
[git-annex web]: https://git-annex.branchable.com/forum/initremote_type__61__web/

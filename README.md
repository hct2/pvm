# Pvm (PowerVM reporting tool)

## Introduction

Pvm is a command line utility which lists various information from one or
more PowerVM (pSeries AIX/Linux) systems.  It is essentially a more user
friendly front end to the lssyscfg and lshwres HMC commands.

Pvm can be used to easily review and compare the state of various
attributes of your systems.  This makes easy to spot anomalies, for
example an adapter that shouldn't be "required" or a non-standard VLAN number.


## Features

- Query managed systems, lpars and their profiles.

- View objects from multiple HMCs and their managed systems in one human
  readable report with aligned columns.

- A "discoverable" CLI.  For example:
  - `pvm` by itself will be give you a list of all possible commands. 
  - `pvm query lpar` will give you a list of all `query lpar` commands.

- A CLI which can be abbreviated (as long as each argument is un-ambiguous).
  For example, `pvm query lpar virtual fc` can be
  abbreviated to `pvm q lpar virt fc` or even `pvm q l v f`.

- No need to install any other Perl modules; Uses only Perl 5.8 Core
  modules supplied with AIX 5.3 and above.

- HMC command output is cached for a period of time (internally configured
  to 1 hour) so that you can re-run the same report without having to
  wait for the HMC commands again. You can override this behaviour with
  a command line option.

## Installation

1. Extract pvm.tar somewhere.
   Anywhere. (You don't have to run pvm as root.)

2. Add the pvm/bin directory (which contains the pvm command) to your PATH.
   Not compulsory, but saves you typing the full path every time.

3. Edit pvm/lib/pvm.conf or make a copy of it in your home directory.
   Set the hmc_names to the list of HMCs you want to query.
   Pvm will discover all managed systems on the listed HMCs, when you
   run you're first query.
   Set the hmc_user if you want pvm to run commands on the HMCs as someone
   other than hscroot.

4. Setup ssh keys to allow your user (the user running pvm) to be
   able to ssh directly to the HMCs without a password.

   Not compulsory, however pvm will ask you for the hscroot password every
   time it tries to run a command on each of the HMCs.

   I would expect most self-respecting PowerVM administrators to have already
   done this at least once before already. Essentially you'll need to create
   a key pair using whatever method you prefer, then use the
   mkauthkeys command on the hmc to add the public key to the HMC.
   Google for `mkauthkeys` and you'll find plenty of examples of how to do this.

## Usage

Run `pvm -?` for usage help.
Run `pvm` to see a list of available commands.
Run `pvm query` to see a list of available commands.

Some example commands to get you started:

  pvm query lpar list                 # list lpars
  pvm query lpar list -?              # show options for command 
  pvm query lpar list format=detail   # one attribute per line
  pvm query profile cpu               # profile cpu attributes
  pvm query profile                   # list all query profile commands
  pvm query lpar virtual ethernet     # lpar (active) virtual ethernet
  query lpar virtual fc               # lpar (active) virtual fc adapters
  query lpar virtual wwpns            # lpar (active) virtual fc wwpns

Note that each of the above commands can be abbreviated to the
following (respectively):

  pvm q l l                 
  pvm q l l -?
  pvm q l l f=d
  pvm q p c  
  pvm q p
  pvm q l v e 
  pvm q l v f 
  pvm q l v w 

## Known Bugs & Issues

- Not all attributes are listed. The various reports have to be specifically
  configured, so if there are important reports/attributes which you
  feel should be included, please let me know.
- Don't trust the comments in the scripts. They need an overhall ;-)

## Future Plans

In it's current form, Pvm is just a reporting tool - it makes no changes
to managed systems (i.e. it doesn't invoke `chsyscfg` or `chhwres`), but
with a little (or a lot) more development it could be much more.

For example, it could be used to compare two profiles, or a profile
with an active lpar configuration. It could apply changes from a profile
to an active configuration, or vice-versa.


## Contact Details

John Buxton
HCT Solutions Ltd
john.buxton2@gmail.com

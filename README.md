# Pvm - PowerVM reporting tool written in Perl

## Introduction

Pvm is a command line utility which lists various information from one or
more PowerVM (pSeries AIX/Linux) systems.  It is essentially a more user
friendly front end to the `lssyscfg` and `lshwres` HMC commands.

Pvm can be used to easily review and compare the state of various
attributes of your systems.  This makes easy to spot anomalies, for
example an adapter that shouldn't be "required" or a non-standard VLAN number.

It is written in Perl due to its ubiquity on AIX.

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

1. Extract `pvm.tar` somewhere.
   Anywhere. (You don't have to run pvm as root.)

2. Add the `pvm/bin` directory (which contains the pvm command) to your PATH.
   Not compulsory, but saves you typing the full path every time.

3. Edit `pvm/lib/pvm.conf` or make a copy of it in your home directory.
   Set the `hmc_names` to the list of HMCs you want to query.
   Pvm will discover all managed systems on the listed HMCs, when you
   run you're first query.
   Set the `hmc_user` if you want `pvm` to run commands on the HMCs as someone
   other than `hscroot`.

4. Setup ssh keys to allow your user (the user running pvm) to be
   able to ssh directly to the HMCs without a password.

   Not compulsory, however pvm will ask you for the hscroot password every
   time it tries to run a command on each of the HMCs.

   I would expect most self-respecting PowerVM administrators to have already
   done this at least once before already. Essentially you'll need to create
   a key pair using whatever method you prefer, then use the
   `mkauthkeys` command on the hmc to add the public key to the HMC.
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
    pvm query lpar virtual fc               # lpar (active) virtual fc adapters
    pvm query lpar virtual wwpns            # lpar (active) virtual fc wwpns

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

## Sample Output

### List managed systems

```sh
$ pvm q s l
# query system list
HMC  Msys   Type     Serial   Time                IP
==== ====== ======== ======== =================== ===============
hmc2 P750_2 8233-E8B 061235P  05/25/2011 11:47:55 192.165.255.249
hmc2 P750_1 8233-E8B 061234P  05/25/2011 11:43:39 192.165.254.248
hmc1 P720_2 8202-E4B ABCD1234 05/25/2011 11:43:27 173.17.255.250
hmc1 P720_1 8202-E4B ABCD1235 05/25/2011 11:43:28 173.17.254.252
```

###List LPAR profiles

```sh
$ pvm q p l
# query profile list
Msys   lpar        profile   mem proc vprocs cap   mode
====== =========== ======= ===== ==== ====== ===== ======
P720_1 P720_1_VIO1 normal   4096  0.5      2 uncap shared
P720_1 P720_1_VIO2 normal   4096  0.5      2 uncap shared
P720_1 lpar1       normal   6144  0.2      2 uncap shared
P720_1 lpar2       normal   6144  1.0      5 uncap shared
P720_1 lpar3       normal   6144  1.0      5 uncap shared
P720_2 P720_2_VIO1 normal   4096  0.5      2 uncap shared
P720_2 P720_2_VIO2 normal   4096  0.5      2 uncap shared
P720_2 dbserver1   normal   6144  0.2      2 uncap shared
P720_2 tsm1        normal   6144  0.2      2 uncap shared
P720_2 webserver1  normal   6144  1.0      5 uncap shared
P750_1 P750_1_VIO1 normal   6144  1.0      3 uncap shared
P750_1 P750_1_VIO2 normal   6144  1.0      3 uncap shared
P750_1 devserv1    normal   4096  0.5      2 uncap shared
P750_1 devtsm1     normal  16384  3.0      6 uncap shared
P750_1 nim1        normal   4096  2.0      3 uncap shared
P750_1 tsm2        normal  16384  1.5      6 uncap shared
P750_2 P750_2_VIO1 normal   4096  1.5      3 uncap shared
P750_2 P750_2_VIO2 normal   4096  1.5      3 uncap shared
P750_2 server1     normal  16384  1.0      5 uncap shared
P750_2 server2     normal   4096  0.4      3 uncap shared
P750_2 server3     normal   4096  0.4      3 uncap shared
```

### List LPAR profile CPU detail

```sh
$ pvm q p cp
# query profile cpu
Msys   lpar        profile mnU dsU mxU mnP dsP mxP Smode Wgt Po
====== =========== ======= === === === === === === ===== === ==
P720_1 P720_1_VIO1 normal  0.1 0.5 2.0   1   2   4 uncap 255 0
P720_1 P720_1_VIO2 normal  0.1 0.5 2.0   1   2   4 uncap 255 0
P720_1 lpar1       normal  0.2 0.2 0.6   1   2   4 uncap 128 0
P720_1 lpar2       normal  0.5 1.0 4.0   3   5  10 uncap 128 0
P720_1 lpar3       normal  0.5 1.0 4.0   3   5  10 uncap 255 0
P720_2 P720_2_VIO1 normal  0.1 0.5 2.0   1   2   4 uncap 255 0
P720_2 P720_2_VIO2 normal  0.1 0.5 2.0   1   2   4 uncap 255 0
P720_2 dbserver1   normal  0.2 0.2 0.6   1   2   4 uncap 128 0
P720_2 tsm1        normal  0.2 0.2 0.6   1   2   4 uncap 128 0
P720_2 webserver1  normal  0.5 1.0 4.0   3   5  10 uncap 128 0
P750_1 P750_1_VIO1 normal  1.0 1.0 3.0   1   3   6 uncap 128 0
P750_1 P750_1_VIO2 normal  1.0 1.0 3.0   1   3   8 uncap 128 0
P750_1 devserv1    normal  0.3 0.5 1.5   1   2   4 uncap 128 0
P750_1 devtsm1     normal  2.0 3.0 6.0   2   6   8 uncap 128 0
P750_1 nim1        normal  1.0 2.0 6.0   1   3   6 uncap 128 0
P750_1 tsm2        normal  0.7 1.5 5.0   2   6   8 uncap 128 0
P750_2 P750_2_VIO1 normal  1.0 1.5 2.0   2   3   8 uncap 128 0
P750_2 P750_2_VIO2 normal  1.0 1.5 2.0   2   3   8 uncap 128 0
P750_2 server1     normal  0.5 1.0 4.0   3   5  10 uncap 128 0
P750_2 server2     normal  0.3 0.4 1.2   2   3   5 uncap 128 0
P750_2 server3     normal  0.3 0.4 1.2   2   3   5 uncap 128 0
```
### Query active LPAR virtual FC connections

```sh
$ pvm q l v f
# query lpar virtual fc
Msys   lpar    Slot Type   Rlpar  Rslot Rq St
====== ======= ==== ====== ====== ===== == ==
P570_1 prod01     8 client ios3a     15 0  1
P570_1 prod01     9 client ios3b     15 0  1
P570_1 prod01    10 client ios3a     16 0  1
P570_1 prod01    11 client ios3b     16 0  1
P570_1 ios3a     15 server prod01     8 0  1
P570_1 ios3a     16 server prod01    10 0  1
P570_1 ios3b     15 server prod01     9 0  1
P570_1 ios3b     16 server prod01    11 0  1
```

### List all possible commands

```sh
$ pvm
Possible commands:
  query io bus
  query io unit
  query lpar cpu
  query lpar io
  query lpar list
  query lpar memory
  query lpar serial
  query lpar virtual ethernet
  query lpar virtual fc
  query lpar virtual scsi
  query lpar virtual wwpns
  query profile cpu
  query profile io
  query profile list
  query profile memory
  query profile serial
  query profile virtual ethernet
  query profile virtual fc
  query profile virtual scsi
  query profile virtual wwpns
  query reference_codes
  query system cpu
  query system hea logical port
  query system hea logical sys
  query system hea phys phys
  query system hea phys port group
  query system hea phys port list
  query system list
  query system memory
  query system pool
  query system virtual ethernet
  query system virtual fc
  query virtual io
  query virtual max
```  

### List possible "query profile" commands

```sh
$ pvm q p
Possible commands:
  query profile cpu
  query profile io
  query profile list
  query profile memory
  query profile serial
  query profile virtual ethernet
  query profile virtual fc
  query profile virtual wwpns
  query profile virtual scsi
```

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

John Buxton,
HCT Solutions Ltd,
john.buxton2@gmail.com

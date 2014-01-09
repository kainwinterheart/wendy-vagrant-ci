Vagrant box for testing Wendy projects
======================================

Virtual environment to run your tests with Apache::Test

Files and directory tree
------------------------

### cookbooks

Chef cookbooks.

### lib

3rd party packages used inside your project.

### opt

Stuff required to init your environment.

#### env.sql

Additional environment initialization-related queries.

#### wendyinit.sql

Wendy database structure.

### project

Project directory.

#### lib

Your project's packages.

#### opt

##### db.sql

Your project's database structure and stuff.

#### t

Your project's test files.

##### t/conf

Apache config storage.

###### t/conf/extra.conf.in

Apache configuration file.

### roles

Chef roles.

### var

Variable files for your environment.

#### var/wendy

Wendy's var directory.

##### var/wendy/hosts/localhost

Wendy's host's root directory.

Usage
-----

Put your project's files into appropriate directories, then run

	vagrant up

To examine logs and other things, use

	vagrant ssh
	cd /tmp/projectclone

Reference
---------

[Vagrant](http://vagrantup.com/)
[Apache::Test](http://perl.apache.org/docs/general/testing/testing.html)


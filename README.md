Accessable
=========

[Ansible Galaxy enabled](https://galaxy.ansible.com/cevich/accessible)
role to wait for a host to boot, then make sure any low-level Ansible
or system requirements are taken care of.  Finally, it makes an explicit
call to the setup module for fact-gathering.

Requirements
------------

Same as stock Ansible ``2.3+``.

Role Variables
--------------

``accessible_cmd``:
    The command, when executed successfully on the subject-host, signals
    availability and readiness.  Defaults to ``/bin/true``.

``accessible_retries``:
    The number of times to retry ``accessible_cmd`` before failing
    subject host.  Also see ``accessible_delay`` below.  Defaults to ``20``.

``accessible_delay``:
    The number of seconds to wait between each retry of ``accessible_cmd``.
    Defaults to ``5``.

``accessible_ansible_deps``:
    Lookup table of Ansible dependency installation commands per OS and
    major version.  The lookup is based upon the contents of ``/etc/os-release``
    If no match is found, the ``default`` key is used.

``accessible_gather_subset``:
    After any dependencies are installed, the ``setup`` module will run to gather
    subject-host facts.  This value limits collection to a subset of fact
    plugins.  Defaults to 'network'.


Dependencies
------------

For RHEL systems, this role depends on
[cevich.subscribed](https://galaxy.ansible.com/cevich/subscribed) being
available (by name).


Example Playbook
----------------

```yaml
    - hosts: all
      gather_facts: False
      roles:
        - accessible
```

License
-------

    Wait for, and make ready, a Fedora, Ubuntu, CentOS, or RHEL subject host.
    Copyright (C) 2018  Christopher C. Evich

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.


Author Information
------------------

Causing trouble and inciting mayhem with Linux since Windows 98


Continuous Integration
----------------------

Travis CI: [![Build Status](https://travis-ci.org/cevich/accessible.svg?branch=master)](https://travis-ci.org/cevich/accessible)

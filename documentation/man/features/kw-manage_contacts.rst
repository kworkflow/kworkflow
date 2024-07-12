====================================
kw-manager - Manage groups of emails 
====================================

.. _manager-doc:

SYNOPSIS
========
  | *kw manager* (-c | \--group-create) [<name>]
  | *kw manager* (-r | \--group-remove) [<name>]
  | *kw manager* \--group-rename "[<old_name>]:[<new_name>]"
  | *kw manager* \--group-add "[<group_name>]:[<ctt1_name>] <[<ctt1_email>]>, ..."
  | *kw manager* \--group-remove-email "[<group_name>]:[<ctt1_name>] <[<ctt1_email>]>, ..."
  | *kw manager* \--group-show=[<group_name>]

DESCRIPTION
===========

The `kw-manager` is an email group manager feature that provides a comprehensive 
interface for managing email groups, streamlining the process of organizing and
maintaining contact lists. This feature allows users to:

- Create new email groups
- Delete existing email groups
- Add contacts to a group
- Remove contacts from a group
- Rename email groups
- View all groups
- View contacts within a specific group

By integrating with the `kw send-patches` feature, email group manager simplifies 
the patch submission process by making it possible to send a patch directly to a 
group of contacts. Furthermore, it also guarantees the possibility of saving a 
group after sending a patch.

OPTIONS
=======
-c, \--group-create [<name>]:
  Create a new group with the specified name. The group will be stored in the 
  manager_email_group table, which contains the group ID, name, and creation date.

-r, \--group-remove [<name>]:
  Remove an existing group with the specified name. This action deletes the 
  group from the manager_email_group table and also removes the associated contacts 
  in the manager_email_contact_group table.

\--group-rename "[<old_name>]:[<new_name>]":
  Rename an existing group from old_name to new_name. The change will be reflected 
  in the manager_email_group table.

\--group-add "[<group_name>]:[<ctt1_name>] <[<ctt1_email>]>, [<ctt2_name>] <[<ctt2_email>]>, ...":
  Add contacts to an existing group. Contacts are stored in the manager_email_contact
  table and the association between contacts and groups is stored in the 
  manager_email_contact_group table.

\--group-remove-email "[<group_name>]:[<ctt1_name>] <[<ctt1_email>]>, [<ctt2_name>] <[<ctt2_email>]>, ...":
  Remove contacts from an existing group. This action updates the 
  manager_email_contact_group table to reflect the removal.

\--group-show[=<group_name>]:
  Show all existing groups or contacts of a specific group if group_name is
  provided. Group information is retrieved from the manager_email_group 
  table and contact information from the manager_email_contact table.

EXAMPLES
========
To create a new group named "NewGroup"::

  kw manager -c "NewGroup"

To remove an existing group named "OldGroup"::

  kw manager -r "OldGroup"

To rename an existing group from "OldGroup" to "NewGroup"::

  kw manager --group-rename "OldGroup"

To add contacts (John Doe and Jane Smith) to an existing group named "ExistingGroup"::

  kw manager --group-add "ExistingGroup: John Doe john.doe@example.com, Jane Smith jane.smith@example.com"

To remove John Doe from an existing group named "ExistingGroup"::

  kw manager --group-remove-email "ExistingGroup John Doe john.doe@example.com"

To display all existing email groups::

  kw manager --group-show

To display contacts of a specific group named "ExistingGroup"::

  kw manager --group-show=ExistingGroup

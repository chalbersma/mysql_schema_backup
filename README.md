# mysql_schema_backup

**This is not a full backup tool.** It will only check and backup changes
in your schema (Using the [mysqldump](https://mariadb.com/kb/en/mariadb/mysqldump/) command).
It's designed to work with a git repository as the backup location.
When changes are detected it should use the [`mailx`](https://linux.die.net/man/1/mailx)
to send a notification email when changes are detected to the email configured.


This was a tool that was used at my last job (stripped of workplace specific
information) that we used to keep an eye on our database. Because of some
old processes we had database that had regular schema changes that weren't
properly handled by change control. Occasionally someone would make a change
that would break something. This gave us the means to reset our schema to the
proper state. **This should be used in conjunction with a better backup tool**, preferably one
that backs up data in addition to schema.

The big benefit here is if you have got a database or series of database (think dev environment)
that have a lot of changes and you want a historical record of just what changes have been made
for whatever reason this might be good for you.

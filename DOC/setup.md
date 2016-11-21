# Install `mysql_schema_backup` Script

## Backup

* Stash the old Stuff

```
cp -r /opt/dbcompare_code /tmp/dbcompare_code.old
rm -r /opt/dbcompare_code
# Above will fail on new install
```

## Rollout 

### Install

* Make install dir on host.

```
mkdir -p /opt/dbcompare_code # Only if non-existant
chown mysql:mysql /opt/dbcompare_code
```

* Get check from `ssysrepo1`. Note that this URL will always be at least one behind HEAD.

```
wget --output-document /tmp/dbcompare_code.tgz "http://link/to/release"
```

* Place the Scripts

```
cd /opt/dbcompare_code
tar -xvzf /tmp/dbcompare_code.tgz --strip 1
chown -R mysql:mysql /opt/dbcompare_code
chmod +x /opt/dbcompare_code/dbcompare.sh
```

* Setup the SSH Keys for Repository. May need to create keys if needed.

	```
	su - mysql -s /bin/bash
	ssh-copy-id dbcompare@repo_host.domain
	# Follow Prompts
	ssh-keyscan repo_host.domain
	ssh 'dbcompare@wrepo_host.domain'
	```

* Setup Repository for Comparisons (As Root)

	```
	su - mysql -s /bin/bash
	cd /var/lib/mysql/
	git clone ssh://dbcompare@repo_host.domain/var/lib/git/dbcompare_schema.git
	```

* Setup MySQL User

	```
	CREATE USER 'dbcompare'@'localhost' IDENTIFIED BY 'REDACTED';
	```

* Setup Select for MySQL User

	```
	GRANT SELECT ON *.* TO 'dbcompare'@'localhost';
	GRANT SHOW VIEW ON *.* TO 'dbcompare'@'localhost';
	GRANT EXECUTE ON *.* TO 'dbcompare'@'localhost';
	```

* Setup Log Rotate

	```
	cp /opt/dbcompare_code/dbcompare_log_rotate /etc/logrotate.d/dbcompare
	```

* Be sure to review the conf file to make sure everything there makes sense (`/opt/dbcompare_code/dbcompare.conf`).

* Crontab For this Item. `crontab -e -u mysql`. **Do Not Place this in Root Crontab**

	```
	# DBCOMPARE Script
	0 */4 * * * /opt/dbcompare_code/dbcompare.sh -c /opt/dbcompare_code/dbcompare.conf >> /opt/dbcompare_code/dbcompare.log 2>&1
	```

## Testing

* Test the system.

```
su - mysql -s /bin/bash
/opt/dbcompare_code/dbcompare.sh -c /opt/dbcompare_code/dbcompare.conf 
```

# Red: A real-world case study

## Computer Tech Expo of Northwest Florida

A local group of techies ("the board") puts on an annual **Compputer
Tech Expo** which we have held annually since 2007. Lately we have
been trying to better organize and establish a good database of past
and prospective attendees. We also want to be able to generate good
rosters needed for expediting accurate sign-in of attendees.

After a thorough scrub and cleaning of the fragmented
comma-separated-variable (CSV) data files held by several people and
collected over the years, we have distilled our contact list into a
single CSV data file in the following format:

``` perl6
last-name,first-name.emai1,email2,...,emailN,yyy1,yyy2,yyy3p
```

where the e-mails are distinguished by a single '@' in a field,
attendance years are indicated by a smart match (`~~ /(\d**4) (:i
p)?/`), and a presentation year is indicated by a trailing 'p' on a
matched year.

A sample data file is found [here](./data/attendees.csv).  (NOTE: The
data file example is somewhat simplified to ease parsing for this
study. The actual data file allows spaces in names and handles casing
adjustments as needed.)

### SQL tables

Using a conventional RDBMS we would use use the following tables for
our current needs:

``` perl6
create table person (
   key   varchar(255) unique not null,
   last  varchar(255) not null,
   first varchar(255) not null
   notes varchar(255)
);

create table attend (
   person_key varchar(255) not null,
   year       integer not null,
   notes      varchar(255),
   UNIQUE     (person_key, year)
);

create table present (
   person_key varchar(255) not null,
   year       integer not null,
   notes      varchar(255),
   UNIQUE     (person_key, year)
);

create table email (
   person_key varchar(255) not null,
   email      varchar(255) not null,
   notes      varchar(255),
   status     integer,
   UNIQUE     (person_key, email)
);
```

Queries using the tables will be to determine or provide:

- alphabetical list all contacts by last name, first name,
  and include all known emails in alpha order
- number of attendees per year
- number of presenters per year
- for a person, what years was the person an attendee or
  a presenter
- a list of all known valid emails for upload to a mail server
- a list of persons who unsubscribed to our mailing list
- various email status reports

The goal is to create those tables and query them with **Red**.

### Red models

Translating the SQL tables into **Red** models should represent
a person with all the attributes in the SQL tables, including
the implied relationships among the tables by the common
**person_key** found in all the tables.
The load script, described next, accomplishes that goal.

We created a Perl 6 script to (1) create **Red** models of our desired
database models (2), read the CSV data file, and (3) load an
SQLite database file with the results.  The script is [load-db.p6](./load-db.p6).
Note we use a unique, generated key for each entry, and that key has
been validated with all the data prior to loading the database. In the
instance of a duplicate key, we would add another field to the
key and so document it.

We created a separate script to query the SQLite database. The script is
[query-db.p6](./query-db.p6) **[a WIP]**.

We also created a script to update the database:
[update-db.p6](./update-db.p6) **[a WIP]**.

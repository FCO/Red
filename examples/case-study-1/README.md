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

```
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

### The problem with emails

In most using applications I'm familiar with, an email uniquely
defines a person since it cannot be used by another person.  That
makes sense for most businesses. However, many of our attendees are
couples who share emails, thus we need to accomodate that in our
registration lists so as not to confuse our volunteer helpers. Also,
some attendees have used mutiple emails over the years so we have to
accommodate that, too.  Hence the separate email table.

### Raw data tables

The data collected in raw form looks like this:

```
last first emailN attendN presentN
```

where the 'N' on a field name means multiple entries
are possible with no change in the other fields. Proper
database design leads us to normalized tables looking
like this in pseudo table form:

```
person:
id last first

email:
email person-id

attend:
year person-id

present:
year person-id
```

where the person-id acts as a foreign key in
each table thus making each data pair unique.

### SQL tables

Using a conventional RDBMS we then translate the raw
tables into SQL:

```
create table person_tbl (
   id    integer serial,                 -- primary key
   key   varchar(255) unique not null,
   last  varchar(255) not null,
   first varchar(255) not null,
   notes varchar(255)
);

create table attend_tbl (
   year       integer not null,
   notes      varchar(255),
   person_id  integer references person_tbl(id)
);

create table present_tbl (
   year       integer not null,
   notes      varchar(255),
   person_id  integer references person_tbl(id)
);

create table email_tbl (
   email      varchar(255) not null,
   notes      varchar(255),
   status     integer,
   person_id  integer references person_tbl(id)
);
```

Some queries using the tables will be to determine or provide:

1. alphabetical list of all contacts by last name, first name,
   registration number, and include all known emails in alpha order
2. number of attendees per year
3. number of presenters per year
4. for a person, what years was the person an attendee or a presenter
5. a list of all known valid emails for upload to a mail server
6. a list of persons who unsubscribed to our mailing list
7. various email status reports

The goal is to create those tables and query them with **Red**.
The Red models and the load script, described next, accomplishes that goal.

### Red models

Translating the SQL tables into **Red** models should represent
a person with all the attributes in the SQL tables, including
the relationships among the tables by the common
**person_id** found in all the tables.
The resultant Red models are in the './lib' directory.

#### Part 1 - Creating the database

We created a Perl 6 script to (1) create **Red** models of our desired
database models (2), read the CSV data file, and (3) load an SQLite
database file with the results.  The script is
[load-db.p6](./load-db.p6).  Note we use a unique, generated secondary
key in addition to the primary key (id) for each entry, and that key
has been validated with all the data prior to loading the database. In
the rare instance of a duplicate key, we would add another field to
the key and so document it (and migrate the database to a version with
the new seconday key but preserving the primary key.

#### Part 2 - Querying the database

After we created the dabatase, we will then start to use it with
various queries as we prepare for the next event.

We created a separate script to query the SQLite database. The script
is [query-db.p6](./query-db.p6) **[a WIP]**. It will be updated as we
determine new reports are needed.

Some example CSV files containing typical reports needed are shown:
(1) current contact list
[contacts-2019-04-01.csv](./data/contacts-2019-04-01.csv), and (2)
[attendance-2020.csv](./data/update-2020.csv) and

#### Part 3 - Updating the database

(1) updates between events
[update-2019-04-01.csv](./data/update-2019-04-01.csv), and (2)
[attendance-2020.csv](./data/update-2020.csv) and

We also created a script to update the database:
[update-db.p6](./update-db.p6) **[a WIP]**.


#### Part 4 - Preparation for the next event (2020)
There are two reports needed in preparation for the next event

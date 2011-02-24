Galleruby
=========

Galleruby is a simple Ruby script to automatically generate a static HTML
gallery (series of different albums) for your local photo collection. It's
written to publish my personal photos on Amazon S3. I just run this script then
s3sync.rb the resulting output to my S3 bucket.

It's not very configurable, and it makes some assumptions that might not be true
for your picture setup. I'm aware of the following ones:
 * All photos need the EXIF DateTime tag set.
 * Files need to have jpg or jpeg as their extension (case insensitive).
 * Your albums are sorted into directories in a common source directory, and
   albums do not have sub-directories.

As an example of the latter, this is similar to what my local layout is:
    ~/Pictures/Events/
        Birthday party 2009/
            IMG_3101.JPG
            IMG_3102.JPG
            ...
        Crazy Galleruby release party/
            IMG_3509.JPG
            IMG_3512.JPG
            ...

If you remove any of these limitations, or find others, please let me know! :-)

Galleruby isn't very user-friendly, but it gets the job done for me - and maybe
it'll get the job done for you too! (or maybe some day grow into something more
general, if I get some user feedback)

Dependencies
============

Galleruby has two external gem dependencies:
 * RMagick
 * HAML

You can install these using:
    gem install rmagick haml

Using Galleruby
===============

First, Galleruby  identifies albums eligible for upload by looking for a
.galleruby.yaml file in the album directory. This file is expected to initially
contain the user-displayed title of the album (e.g. "Birthday party!") and the
shortname of the album, which is what the server-side output directory will be
called (e.g.  "birthdayparty").

So, to get started, you need to generate these files using the make_titles.rb
script. It will suggest defaults you can use by pressing enter - and if you
don't want a directory included, press ctrl+D and it'll forever skip this
direcotry when you run make_titles.rb (and not create a .galleruby.yaml). To
revert this behavior for a directory, delete the .galleruby.skip file.

Second, you just need to run gallerubify - but copy config.yml.dist to
config.yml and edit it first. Running gallerubify will take some time, as it's
generating three resized versions of your files for publishing. You can change
what these sizes are by editing config.yml.

Third, you need to put the static directory as 'galleruby' in your output dir:
    cp -r static output/galleruby

Example
=======

Here's how you'd get started, assuming the above layout. Notice that defaults
were accepted for most values except the title of the birthday party album, and
that we skipped publishing "Very private photos" by pressing ctrl-D.

    $ ./make_titles.rb ~/Pictures/Events
    > Directory Birthday party 2009, 19 files
       What should the title be? [Birthday party 2009]
    Birthday party!
       What should the link name be? [birthdayparty]

    > Directory Crazy Galleruby release party, 54 files
       What should the title be? [Crazy Galleruby release party]
               
       What should the link name be? [crazygallerubyreleaseparty]

    > Directory Very private photos, 5 files
       What should the title be? [Very private photos]
    ^D
       Skipping album

    $ ./gallerubify.rb ~/Pictures/Events
    Birthday party 2009: Processing album
    Birthday party 2009: Rendering HTML
    Crazy Galleruby release party: Processing album
    Crazy Galleruby release party: Rendering HTML
    All done! Generating index.

    $ cp -r static output/galleruby
    $ s3sync.rb output mybucket:

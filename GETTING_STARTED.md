If you're having trouble installing Galleruby, see [the install guide][install].

Using Galleruby
===============

First, Galleruby identifies albums eligible for upload by looking for a
.galleruby.yml file in the album directory. This file is expected to initially
contain the user-displayed title of the album (e.g. "Birthday party!") and the
shortname of the album, which is what the server-side output directory will be
called (e.g.  "birthdayparty").

So, to get started, you need to generate these files using the make_titles
script. It will suggest defaults you can use by pressing enter - and if you
don't want a directory included, press ctrl+D and it'll forever skip this
directory when you run make_titles (and not create a .galleruby.yml). To revert
this behavior for a directory, delete the .galleruby.skip file.
    make_titles ~/Pictures/Albums

Second, you just need to run gallerubify - but copy config.yml.dist to
config.yml and edit it first. Running gallerubify will take some time, as it's
generating three resized versions of your files for publishing. You can change
what these sizes are by editing config.yml.
    gallerubify --title "Joe's Gallery" ~/Pictures/Albums

Third, you need to put the static directory in your output dir:
    cp -r static output/

Example
=======

Here's how you'd get started, assuming the above layout. Notice that defaults
were accepted for most values except the title of the birthday party album, and
that we skipped publishing "Very private photos" by pressing ctrl-D.

    $ make_titles ~/Pictures/Albums
    > Directory Hiking at Daley Ranch, 6 files
       What should the title be? [Hiking at Daley Ranch]

       What should the link name be? [hikingatdaleyranch]

    > Directory Joshua Tree Climbing, 11 files
       What should the title be? [Joshua Tree Climbing]

       What should the link name be? [joshuatreeclimbing]

    > Directory Very Private Album, 1 files
       What should the title be? [Very Private Album]
    ^D
       Skipping album

    $ gallerubify --title "Joe's Gallery" ~/Pictures/Albums
    Hiking at Daley Ranch: Processing album
    Hiking at Daley Ranch: Rendering HTML
    Joshua Tree Climbing: Processing album
    Joshua Tree Climbing: Rendering HTML
    All done! Generating index.

    $ s3sync.rb -vrp output/ my_gallery_bucket:

[install]: /jorgenpt/galleruby/INSTALLING.md

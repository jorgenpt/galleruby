Galleruby
=========

Galleruby is a simple Ruby script to automatically generate a static HTML
gallery (series of different albums) for your local photo collection. It's
written to publish my personal photos on Amazon S3. I just run this script then
s3sync.rb the resulting output to my S3 bucket.

You can see an example setup of Galleruby running on Amazon S3 here:

[http://galleruby.devsoft.no](http://galleruby.devsoft.no)

It's not very configurable, and it makes some assumptions that might not be true
for your picture setup. I'm aware of the following ones:
* All photos need the EXIF DateTime tag set.
* Files need to have jpg or jpeg as their extension (case insensitive).
* Your albums are sorted into directories in a common source directory, and albums do not have sub-directories.

If you remove any of these limitations, or find others, please let me know! :-)

As an example of the layout, this is what
[http://galleruby.devsoft.no](http://galleruby.devsoft.no) has locally:
    ~/Pictures/Albums/
        Hiking at Daley Ranch/
            IMG_0832.JPG
            IMG_0855.JPG
            IMG_0864.JPG
            IMG_0868.JPG
            IMG_0877.JPG
            IMG_0890.JPG
        Joshua Tree Climbing/
            IMG_4420.JPG
            IMG_4425.JPG
            IMG_4428.JPG
            IMG_4429.JPG
            IMG_4437.JPG
            IMG_4450.JPG
            IMG_4455.JPG
            IMG_4458.JPG
            IMG_4460.JPG
            IMG_4461.JPG
            IMG_4467.JPG

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

First, Galleruby identifies albums eligible for upload by looking for a
.galleruby.yml file in the album directory. This file is expected to initially
contain the user-displayed title of the album (e.g. "Birthday party!") and the
shortname of the album, which is what the server-side output directory will be
called (e.g.  "birthdayparty").

So, to get started, you need to generate these files using the make_titles.rb
script. It will suggest defaults you can use by pressing enter - and if you
don't want a directory included, press ctrl+D and it'll forever skip this
directory when you run make_titles.rb (and not create a .galleruby.yml). To
revert this behavior for a directory, delete the .galleruby.skip file.
    ./make_titles.rb ~/Pictures/Albums

Second, you just need to run gallerubify - but copy config.yml.dist to
config.yml and edit it first. Running gallerubify will take some time, as it's
generating three resized versions of your files for publishing. You can change
what these sizes are by editing config.yml.
    ./gallerubify.rb ~/Pictures/Albums

Third, you need to put the static directory in your output dir:
    cp -r static output/

Example
=======

Here's how you'd get started, assuming the above layout. Notice that defaults
were accepted for most values except the title of the birthday party album, and
that we skipped publishing "Very private photos" by pressing ctrl-D.

    $ ./make_titles.rb ~/Pictures/Albums
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

    $ ./gallerubify.rb ~/Pictures/Albums
    Hiking at Daley Ranch: Processing album
    Hiking at Daley Ranch: Rendering HTML
    Joshua Tree Climbing: Processing album
    Joshua Tree Climbing: Rendering HTML
    All done! Generating index.

    $ cp -vr static output/
    static -> output/static
    static/close.png -> output/static/close.png
    static/galleruby.css -> output/static/galleruby.css
    static/galleruby.js -> output/static/galleruby.js
    static/jquery-1.5.min.js -> output/static/jquery-1.5.min.js
    static/next.png -> output/static/next.png
    static/previous.png -> output/static/previous.png

    $ s3sync.rb -vrp output/ my_gallery_bucket:

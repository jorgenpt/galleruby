* For help installing Galleruby, see [the installation guide][installing].
* To see how to run Galleruby, see [the usage guide][guide].

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

[guide]: /jorgenpt/galleruby/blob/master/GETTING_STARTED.md
[installing]: /jorgenpt/galleruby/blob/master/INSTALLING.md

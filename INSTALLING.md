Installing galleruby
====================

The latest stable version of galleruby is hosted on [RubyGems][rubygems], and
can be installed by running:

    gem install galleruby

This will install RMagick and HAML too, if needed. If you're having trouble
getting RMagick installed, see below under *Dependencies*.

If you're working on the source, you'll want to install the dependencies using
Bundler, then running:

    rake install

That'll create a gem from your current source and install it.

Dependencies
============

Galleruby has two external gem dependencies:

* RMagick
* HAML

These should be fulfilled by simply running:

    gem install galleruby

If you're checking out the source, you can manually install these using:

    bundler install

RMagick is a bit tricky, as it depends on ImageMagick or GraphicsMagick being
installed. You can install ImagMagick using [this installer][magick-installer]
or using [Homebrew][homebrew] and running:

    brew install imagemagick

What now?
=========

Once you have Galleruby installed, read [the getting started guide][guide] to
see how to generate your very own gallery!

[magick-installer]: https://github.com/maddox/magick-installer
[homebrew]: https://github.com/mxcl/homebrew
[rubygems]: http://www.rubygems.org/
[guide]: GETTING_STARTED.md

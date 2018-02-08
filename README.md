# Campbell
## Some utilities for Campbell logger format files (TOB3) in Python and IDL

Campbell Scientific (https://www.campbellsci.com/), in the following as CSI, provides a wide range of measurement devices and dataloggers.
These loggers often create files in an internal format (TOB3) for which CSI provides utilities within LoggerNet (Progamm for Communications and Task related to loggers), 
which allow the user to transfer them into more accessable formats like TOA5 or TOB1. 

The conversion may take some time but offer up options such as a repair utility. Often this is already enough, but sometimes
a user wants a more direct method. For this purpose some function are available here to be used.

For documentation about the file formats, see appendix B of the LoggerNet manual at https://s.campbellsci.com/documents/cn/manuals/loggernet.pdf

There are some differences between the utilities: The python TOB3 reader is somewhat slower, because of how the frames are disentangled. My guess is, that this could be improved. The python utilites contains an automatic filetype detection, and if it doesn't find one gives prints a message that you could add one yourself for this filetype. Additionally, the python one can read in the csixml format as well.

## Bugs
Since the provided files have been used on different files some bugs have been filtered out, but there is always more! Especially the TOB3 files require real datafiles to test

## Testing 
None

## Usage
Try out if you think it'll help you out

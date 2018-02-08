# Campbell
## Some utilities for Campbell logger format files (TOB3) in Python and IDL

Campbell Scientific (https://www.campbellsci.com/), in the following as CSI, provides a wide range of measurement devices and dataloggers.
These loggers often create files in an internal format (TOB3) for which CSI provides utilities within LoggerNet (Progamm for Communications and Task related to loggers), 
which allow the user to transfer them into more accessable formats like TOA5 or TOB1. 

The conversion may take some time but offer up options such as a repair utility. Often this is already enough, but sometimes
a user wants a more direct method. For this purpose some function are available here to be used.

For documentation about the file formats, see appendix B of the LoggerNet manual at https://s.campbellsci.com/documents/cn/manuals/loggernet.pdf

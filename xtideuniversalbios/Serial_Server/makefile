######################################################################
#
# Project:     XTIDE Universal BIOS, Serial Port Server
#
# File:        makefile
#
# Use with GNU Make or Microsoft Nmake
# Build with Microsoft Visual C++ 2010 or Windows SDK v7.1
#
# Also works with Open Watcom C/C++ Version 1.9
#

HEADERS = library/Library.h win32/Win32File.h win32/Win32Serial.h library/File.h library/FlatImage.h

CXX = cl
CXXFLAGS = /Ox /DWIN32

WIN32OBJS = build/win32.obj build/checksum.obj build/serial.obj build/process.obj build/image.obj

build/serdrive.exe:	$(WIN32OBJS)
	@$(CXX) /Febuild/serdrive.exe $(WIN32OBJS)

build/win32.obj:	win32/Win32.cpp $(HEADERS)
	@$(CXX) /c $(CXXFLAGS) win32/Win32.cpp /Fobuild/win32.obj

build/checksum.obj:	library/Checksum.cpp $(HEADERS)
	@$(CXX) /c $(CXXFLAGS) library/Checksum.cpp /Fobuild/checksum.obj

build/serial.obj:	library/Serial.cpp $(HEADERS)
	@$(CXX) /c $(CXXFLAGS) library/Serial.cpp /Fobuild/serial.obj

build/process.obj:	library/Process.cpp $(HEADERS)
	@$(CXX) /c $(CXXFLAGS) library/Process.cpp /Fobuild/process.obj

build/image.obj:	library/Image.cpp $(HEADERS)
	@$(CXX) /c $(CXXFLAGS) library/Image.cpp /Fobuild/image.obj


release:	build/serdrive.exe
	@echo Compressing with UPX...
	@upx -qq --ultra-brute build/serdrive.exe
	@echo Done!

clean:
	@del /q build\*.*


build/checksum_test.exe:	library/Checksum.cpp
	@$(CXX) /Febuild/checksum_test.exe /Ox library/Checksum.cpp /Fobuild/checksum_test.obj -D CHECKSUM_TEST


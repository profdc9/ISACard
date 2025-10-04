###############################################################################
# Makefile to build set block device command                                  #
#                                                                             #
# Valid makefile targets are:                                                 #
# all		Removes existing files and builds binary file in \Build           #
# clean		Removes all files from \Build                                     #
#                                                                             #
# Build directory must be created manually if it does not exist.              #
#                                                                             #
###############################################################################

###########################################
# Source files and destination executable #
###########################################

# Assembly source code file (*.asm):
SRC_ASM = Src/Main.asm

# Program executable file name without extension:
PROG = setblkdv
EXTENSION = com


#######################################
# Destination and include directories #
#######################################

# Directory where binary file will be compiled to
BUILD_DIR = Build

# Subdirectories where included files are:
HEADERS = Inc/
HEADERS += Src/

# Subdirectories where library files are:
LIBS = 
HEADERS += $(LIBS)


#################################################################
# Assembler preprocessor defines.                               #
#################################################################
DEFINES = 

###################
# Other variables #
###################

# Add -D in front of every preprocessor define declaration
DEFS = $(DEFINES:%=-D%)

# Add -I in front of all header directories
IHEADERS = $(HEADERS:%=-I%)

# Path + target file to be built
TARGET = $(BUILD_DIR)/$(PROG)


#########################
# Compilers and linkers #
#########################

# Make
MAKE = make

# Assembler
AS = nasm

# use this command to erase files.
RM = rm -f


#############################
# Compiler and linker flags #
#############################

# Assembly compiler flags
ASFLAGS = -f bin				# Produce binary object files
ASFLAGS += $(DEFS)				# Preprocessor defines
ASFLAGS += $(IHEADERS)			# Set header file directory paths
ASFLAGS += -Worphan-labels		# Warn about labels without colon
ASFLAGS += -Ox					# Optimize operands to their shortest forms


############################################
# Build process. Actual work is done here. #
############################################

.PHONY: all at xtplus xt clean release

all: clean release
	@echo All done!

xt:
	@$(AS) "$(SRC_ASM)" $(ASFLAGS) $(DEFS_XT) -l"$(TARGET)_xt.lst" -o"$(TARGET).$(EXTENSION)"
	@echo XT version "$(TARGET).$(EXTENSION)" built.

clean:
	@$(RM) $(BUILD_DIR)\*.*
	@echo Deleted "(*.*)" from "$(BUILD_DIR)/"

release: xt
	@cp Build/setblkdv.com ~/bios
	@echo Done! XT version is ready for release.

xt_unused: xt
	@$(AS) "$(SRC_ASM)" $(ASFLAGS) $(DEFS_XT) -o"$(TARGET)_xt_unused.asm" -E -DCHECK_FOR_UNUSED_ENTRYPOINTS
	@perl ..\Tools\unused.pl $(TARGET)_xt.lst $(TARGET)_xt_unused.asm


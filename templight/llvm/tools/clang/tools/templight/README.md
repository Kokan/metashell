# Templight 2.0 - Template Instantiation Profiler and Debugger

Templight is a Clang-based tool to profile the time and memory consumption of template instantiations and to perform interactive debugging sessions to gain introspection into the template instantiation process.

**Disclaimer**: Templight is still at a very preliminary state. We hope to get as much early adoption and testing as we can get, but be aware that we are still experimenting with the output formats and some of the behaviors. 

## Table of Contents

- [Templight Profiler](#templight-profiler)
- [Templight Debugger](#templight-debugger)
- [Getting Started](#getting-started)
 - [Getting and Compiling Templight](#getting-and-compiling-templight)
 - [Invoking Templight](#invoking-templight)
- [Using the Templight Profiler](#using-the-templight-profiler)
 - [Default Output Location](#default-output-location)
 - [Converting the Output Format](converting-the-output-format)
- [Using the Templight Debugger](#using-the-templight-debugger)
- [Using Blacklists](#using-blacklists)
- [Inspecting the profiles](#inspecting-the-profiles)
- [Credits](#credits)

## Templight Profiler

The templight profiler is intended to be used as a drop-in substitute for the clang compiler (or one of its variants, like clang-cl) and it performs a full compilation, *honoring all the clang compiler options*, but records a trace (or history) of the template instantiations performed by the compiler for each translation unit.

The profiler will record a time-stamp when a template instantiation is entered and when it is exited, which is what forms the compilation-time profile of the template instantiations of a translation unit. The total memory consumption can also be recorded at these points, which will skew the time profiles, but provide a profile of the memory consumed by the compiler during the template instantiations.

The profiler is enabled by the templight option `-profiler`, and it supports the following additional templight options:

 - `-stdout` - Output template instantiation traces to standard output (mainly for piping / redirecting purposes). Warning: you need to make sure the source files compile cleanly, otherwise, the output will be corrupted by warning or error messages.
 - `-memory` - Profile the memory usage during template instantiations.
 - `-safe-mode` - Output Templight traces without buffering, not to lose them at failure (note: this will distort the timing profiles due to file I/O latency).
 - `-ignore-system` - Ignore any template instantiation located in system-includes (-isystem), such as from the STL.
 - `-output=<file>` - Write Templight profiling traces to <file>. By default, it outputs to "current_source.cpp.trace.<format-extension>" or "current_source.cpp.memory.trace.<format-extension>" (if `-memory` is used).
 - `-blacklist=<file>` - Specify a blacklist file that lists declaration contexts (e.g., namespaces) and identifiers (e.g., `std::basic_string`) as regular expressions to be filtered out of the trace (not appear in the profiler trace files). Every line of the blacklist file should contain either "context" or "identifier", followed by a single space character and then, a valid regular expression.

## Templight Debugger

The templight interactive debugger is also a drop-in substitute for the clang compiler, honoring all its options, but it will interrupt the compilation with a console prompt (stdin). The operations of the templight debugger are modeled after the GDB debugger and essentially works the same, *with most commands being the same*, but instead of stepping through the execution of the code (in GDB), it steps through the instantiation of the templates.

In short, the templight debugger is to template meta-programming what GDB is to regular code.

The debugger is enabled by the templight option `-debugger`, and it supports the following additional templight options:

 - `-ignore-system` - Ignore any template instantiation located in system-includes (-isystem), such as from the STL.
 - `-blacklist=<file>` - Specify a blacklist file that lists declaration contexts (e.g., namespaces) and identifiers (e.g., `std::basic_string`) as regular expressions to be ignored by the debugger. Every line of the blacklist file should contain either "context" or "identifier", followed by a single space character and then, a valid regular expression.

**NOTE**: Both the debugger and the profiler **can be used together**. Obviously, if compilation is constantly interrupted by the interactive debugger, the time traces recorded by the profiler will be meaningless. Nevertheless, running the profiler during debugging will have the benefit of recording the history of the template instantiations, for later review, and can also record, with reasonably accuracy, the memory consumption profiles.

## Getting Started

### Getting and Compiling Templight

Templight must be compiled from source, alongside the Clang source code.

1. [Follow the instructions from LLVM/Clang](http://clang.llvm.org/get_started.html) to get a local copy of the **latest svn trunk** of the Clang source code.

2. Clone the templight repository into the clang directories, as follows:
```bash
  (from top-level folder)
  $ cd llvm/tools/clang/tools
  $ mkdir templight
  $ git clone <link-to-clone-templight-github-repo> templight
```

3. Add the templight directory to the `CMakeLists.txt` file. 
  1. Open the file: `llvm/tools/clang/tools/CMakeLists.txt`
  2. Add the line: `add_subdirectory(templight)`
  3. Save and exit the editor.

4. Apply the supplied patch to Clang's source code:
```bash
  (from top-level folder)
  $ cd llvm/tools/clang
  $ svn patch tools/templight/templight_clang_patch.diff
```

5. (Re-)Compile LLVM / Clang:
```bash
  (from top-level folder)
  $ mkdir build
  $ cd build
  $ cmake ../llvm/
  $ make
```

6. If successful, there should be `templight` executables in the `build/bin` folder.

### Invoking Templight

Templight is designed to be a drop-in replacement for the clang compiler. This is because in order to correctly profile the compilation, it must run as the compiler would, honoring all compilation options specified by the user.

Because of this particular situation, the options for templight must be specially marked with `-Xtemplight` to distinguish them from other Clang options. The general usage goes like this:

```bash
  $ templight++ [[-Xtemplight [templight-option]]|[clang-option]] <inputs>
```

Or, for the MSVC-compatible version of templight (analoguous to clang-cl) use as follows:

```bash
  $ templight-cl [[-Xtemplight [templight-option]]|[clang-option]] <inputs>
(OR)
  > templight-cl.exe [[-Xtemplight [templight-option]]|[clang-option]] <inputs>
```

For example, if we have this simple command-line invocation of clang:

```bash
  $ clang++ -Wall -c some_source.cpp -o some_source.o
```

The corresponding templight profiler invocation, with options `-memory` and `-ignore-system` would look like this:

```bash
  $ templight++ -Xtemplight -profiler -Xtemplight -memory -Xtemplight -ignore-system -Wall -c some_source.cpp -o some_source.o
```

Note that the order in which the templight-options appear is not important, and that clang options can be interleaved with templight-options. However, **every single templight-option must be immediately preceeded with `-Xtemplight`**.

As can be seen from that simple example, one can easily substitude the clang command (e.g., `clang++`) with a compound templight invocation (e.g., `templight++ -Xtemplight -profiler -Xtemplight -memory`) and thus, leave the remainder of the command-line intact. That is how templight can be used as a drop-in replacement for clang in any given project, build script or an IDE's build configuration.

If you use CMake and clang with the following common trick:
```bash
  $ export CC=/path/to/llvm/build/bin/clang
  $ export CXX=/path/to/llvm/build/bin/clang++
  $ cmake <path-to-project-root>
```
Then, templight could be swapped in by the same trick:
```bash
  $ export CC="/path/to/llvm/build/bin/templight -Xtemplight -profiler -Xtemplight -memory"
  $ export CXX="/path/to/llvm/build/bin/templight++ -Xtemplight -profiler -Xtemplight -memory"
  $ cmake <path-to-project-root>
```
But be warned that the **cmake scripts will not recognize this compiler**, and therefore, you will have to make changes in the CMake files to be able to handle it. If anyone is interested in creating some CMake modules to deal with templight, please contact the maintainer, such modules would be more than welcomed.

## Using the Templight Profiler

The templight profiler is invoked by specifying the templight-option `-profiler`. By default, if no other templight-option is specified, the templight profiler will output only time profiling data, will use the "yaml" format, and will output to one file per input source file and will append the extension `.trace.yaml` to that file.

For example, running the following:
```bash
  $ templight++ -Xtemplight -profiler -c some_source.cpp
```
will produce a file called `some_source.cpp.trace.yaml` in the same directory as `some_source.cpp`.

It is, in general, highly recommended to use the `-ignore-system` option for the profiler (and debugger too) because instantiations from standard or third-party libraries can cause significant noise and dramatically increase the size of the trace files produced. If libraries like the STL or most of Boost libraries are used, it is likely that most of the traces produced relate to those libraries and not to your own. Therefore, it is recommended to use `-isystem` when specifying the include directories for those libraries and then use the `-ignore-system` templight-option when producing the traces.

*Warning*: Trace files produced by the profiler can be very large, especially in template-heavy code. So, use this tool with caution. It is not recommended to blindly generate templight trace files for all the source files of a particular project (e.g., using templight profiler in place of clang in a CMake build tree). You should first identify specific parts of your project that you suspect (or know) lead to template instantiation problems (e.g., compile-time performance issues, or actual bugs or failures), and then create a small source file that exercises those specific parts and produce a templight trace for that source file.

### Default Output Location

The location and names of the output files for the templight traces needs some explanation, because it might not always be straight-forward. The main problem here is that templight is meant to be used as a drop-in replacement for the compiler (and it actually compiles the code, exactly as the vanilla Clang compiler does it). The problem is that you can invoke a compiler in many different ways. On typical small tests, you would simply invoke the compiler on a single source file and produce either an executable or an object file. In other case, you might invoke it with a list of source files to produce either an executable or a library. And for "real" projects, a build system will generally invoke the compiler for each source file, producing an object file each time, and later invoking the linker separately.

Templight must find a reasonable place to output its traces in all those cases, and often, specifying an output location with `-output` does not really solve the problem (like this problem: multiple source files, one output location?). The only really straight-forward case is with the `-stdout` option, where the traces are simply printed out to the standard output.

**One Source File, One Object File** (without `-output` option): Whenever doing a simple compilation where each source file is turned into a single object file (i.e., when using the `-c` option), then the templight tracer will, by default, output the traces into files located where the output object files are put and with the same name, but with the addition of the templight extensions. In other words, for compilation instructions like `-c some/path/first_source.cpp some/other/path/second_source.cpp`, you would get traces files: `some/path/first_source.o.trace.yaml` and `some/other/path/second_source.o.trace.yaml`. Whichever options you specify to change the location or name of the generate object file, templight traces will follow. In other words, the default trace filenames are derived from the final output object-file names.

**One Source File, One Object File** (with `-output` option): Because the `-output` option cannot deal with multiple files specified, templight will ignore this option in this case. 

**One Source File, (Some Output) File**: If you do any other operation that is like a simple compilation (no linking), such as using the `-S` option to general assembly listings, then the situation is analoguous to when you use the `-c` option (produce object-files). The templight trace file names are simply derived from whatever is the final output file name (e.g., `some_source.s.trace.yaml`). If you invoke templight in a way that does not involve any kind of an output file, then templight falls back to deriving the trace file names from the source file names (e.g., `some_source.cpp.trace.yaml`).

The overall behavior in the above three cases is designed such that when templight is invoked as part of a compilation driven by a build-system (e.g., cmake, make, etc.), which is often done out-of-source, it will output all its traces wherever the build-system stashes the object-files, which is a safe and clean place to put them (e.g., avoid pollution in source tree, avoid possible file-permission problems (read-only source tree), etc..). It is also easy, through most build-systems to create scripts that will move or copy those traces out of those locations (that might be temporary under some setups) and put them wherever is more convenient.

**Many Source Files, (Some Output) File**: If you invoke the compilation of several source files to be linked into a single executable or library, then templight will merge all the traces into a single output file, whose name is derived from the executable or library name. If no output name is specified, the compiler puts the executable into `a.out`, and templight will put its traces into `a.trace.yaml`. If you specify an output file via the `-output` option, then the trace will be put into that file.

### Converting the Output Format

Templight outputs its traces to a Google protocol buffer output format to minimize the size of the files and the time necessary to produce and load the trace files. For convenience, however, a conversion tool is provided, `templight-convert`, to produce other output formats that may be more convenient for third-party applications. Currently, `templight-convert` provides the following output formats:

 - "protobuf": Output in a Google protocol buffer format, which is an efficient binary extensible format. The message definition file is provided, as `templight_message.proto`, so that off-the-shelf protobuf software can be used to read the trace files. The format uses some dictionary-based compression to minimize it's size, therefore, additional steps are necessary to reconstruct the file names and template names.
 - "yaml": A YAML format, which is a simple text-based markup language.
 - "xml": An XML format, the well-known text-based markup language.
 - "text": A simple text file, mostly for human-readability.
 - "nestedxml": An XML format with nested template instantiations instead of a flat begin-end structure (used with "xml").
 - "graphml": A standard XML-like graph markup language, supported by many graph vizualization software.
 - "graphviz": A graph vizualization format, supported by the popular graphviz library and "dot" utility program for rendering diagrams.

The `templight-convert` utility is used as follows:
```bash
    $ templight-convert [options] [input-files]
```

The `templight-convert` utility supports the following options:

 - `-output` or `-o` - Write Templight profiling traces to <output-file>.
 - `-format` or `-f` - Specify the format of Templight outputs (protobuf / yaml / xml / text / graphml / graphviz / nestedxml, default is protobuf).
 - `-blacklist` or `-b` - Use regex expressions in <file> to filter out undesirable traces.
 - `-compression` or `-c` - Specify the compression level of Templight outputs whenever the format allows.
 - `-blacklist=<file>` - Specify a blacklist file that lists declaration contexts (e.g., namespaces) and identifiers (e.g., `std::basic_string`) as regular expressions to be filtered out of the trace (not appear in the profiler trace files). Every line of the blacklist file should contain either "context" or "identifier", followed by a single space character and then, a valid regular expression.

## Using the Templight Debugger

The templight debugger is invoked by specifying the templight-option `-debugger`. When the debugger is launched, it will interrupt the compilation with a console command prompt, just like GDB. The templight debugger is designed to work in a similar fashion as GDB, with many of the same familiar commands and behavior.

Here is a quick reference for the available commands:

`break <template name>`
`b <template name>`
This command can be used to create a break-point at the instantiation (or any related actions, such as argument deductions) of the given template class or function. If the base name of the template is used, like `my_class`, then the compilation will be interrupted at any instantiation in which that base name appears. If an specialization for the template is used, like `my_class<double>`, then the compilation will be interrupted only when this specialization is encountered or instantiated.

`delete <breakpoint index>`
`d <breakpoint index>`
This command can be used to delete a break-point that was previously created with the `break` command. Each break-point is assigned an index number upon creation, and this index number should be used to remove that break-point. Use the `info break` (or `i b`) command to print the list of existing break-points so that the break-point index number can be retrieved, if forgotten.

`run` / `r`
`continue` / `c`
This command (in either forms or their short-hands) will resume compilation until the next break-point is encountered.

`kill` / `k`
`quit` / `q`
This command (in either forms or their short-hands) will resume compilation until the end, ignoring all break-points. In other words, this means "finish the compilation without debugging".

`step` / `s`
This command will step into the template instantiation, meaning that it will resume compilation until the next nested (or dependent) template is instantiated. For example, when instantiating a function template definition, function templates or class templates used inside the body of that function will be instantiated as part of it, and the `step` command allows you to step into those nested instantiations.

`next` / `n`
This command will skip to the end of the current template instantiation, and thus, skipping all nested template instantiations. The debugger will interrupt only when leaving the current instantiation context, or if a break-point is encountered within the nested template instantiations.

`where` / `backtrace` / `bt`
This command can be used to print the current stack of nested template instantiations.

`info <kind>` / `i <kind>`
This command can be used to query information about the state of the debugging session. The `<kind>` specifies one of the following options:
 - `frame` / `f`: Prints the information about the current template instantiation that the debugger is currently interrupted at.
 - `break` / `b`: Prints the list of all existing break-points.
 - `stack` / `s`: This is equivalent to calling `where` / `backtrace` / `bt` directly.

`lookup <identifier>`
`l <identifier>`
This command can be used to perform a look-up operation for a given identifier, within the context of the current template instantiation. This will print out the match(es) that the compiler would make to the given identifier. For example, if you are in the instantiation of a member function of an STL container and lookup an identifier like `value_type`, it will point you to the location of that the declaration that the compiler will associate to that identifier in that context (presumably a nested typedef in the STL container class template). If the identifier refers to a compile-time constant value (e.g., integral constant template argument), this command will also print its value.

`typeof <identifier>`
`t <identifier>`
This command is similar to `lookup` except that instead of showing you the location of the matching identifier (e.g., showing you a nested typedef or a data member) it will show you its type. If the identifier matches a variable, data member, function, or compile-time constant value, this command will show you the type of that object. If the identifier matches a type, it will show you what the actual type (fully instantiated) is. For example, if it matches a typedef or an alias, then the underlying type that it aliases will be shown (e.g., say you are inside the instantiation of the `std::vector<double>::insert` function and issue `typeof value_type`, it should show you `double` as a result).

*Warning*: The templight debugger is still in a *very experimental* phase. You should expect that some of the behaviors mentioned in the above descriptions of the commands will not work as advertized, yet. If you observe any unusual or buggy behaviors, please notify the maintainer and provide an example source file with the sequence of commands that led to the observed behavior.

## Using Blacklists

A blacklist file can be passed to templight (profiler or debugger) to filter entries such that they do not appear in the trace files or do not get involved in the step-through debugging. The blacklist files are simple text files where each line contains either `context <regex>` or `identifier <regex>` where `<regex>` is some regular expression statement that is used to match to the entries. Comments in the blacklist files are preceeded with a `#` character.

The "context" regular expressions will be matched against declaration contexts of the entry being tested. For example, with `context std`, all elements of the std namespace will be filtered out (but note that some elements of std might refer to elements in other implementation-specific namespaces, such as `__gnu_cxx` for libstdc++ from GNU / GCC). Context blacklist elements can also be used to filter out nested instantiations. For example, using `context std::basic_string` would filter out the instantiation of the member functions and the nested templates of the `std::basic_string` class template, but not the instantiation of the class itself. In other words, declaration contexts are not only namespaces, but could also be classes (for members) and functions (for local declarations).

The "identifier" regular expressions will be matched against the fully-scoped entry names themselves. For example, using `identifier std::basic_string` would filter out any instantiation of the `std::basic_string` class template.

*Warning*: Beware of lexical clashes, because the regular expressions could blacklist things that you don't expect. For instance, using `context std` would filter out things in a `lastday` namespace too! It is therefore recommended to make the regular expressions as narrow as possible and use them wisely. For example, we could solve the example problem with `context ^std(::|$)` (match only context names starting with "std" and either ending there or being followed immediately by "::"). Also, an often practical and safer alternative to blacklists is to use the `-ignore-system` option, which ignores all entries coming out of a system-include header (standard headers and anything in directories specified with `-isystem` compiler option), which is not as fine-grained but is often more effective against complex libraries (e.g., STL, Boost, etc.) which can cause a lot of "noise" in the traces.

Note that a pretty well-established convention for template-heavy code is to place implementation details into either `detail` namespace or in an anonymous namespace. Boost library implementers are particularly good with this. Therefore, it can be a good idea to filter out those things if you are not interested in seeing instantiations of such implementation details.

Here is an example blacklist file that uses some of the examples mentioned above:
```bash
    # Filter out anything coming from the std namespace:
    context ^std(::|$)
    
    # Filter out things from libstdc++'s internal namespace:
    context __gnu_cxx
    
    # Filter out anonymous entries (unnamed namespaces or types):
    identifier anonymous
    
    # Filter out boost::something::or::nothing::detail namespace elements:
    context ^boost::.*detail
```

## Inspecting the profiles

Any contribution or work towards such an application is more than welcomed! The formats of the traces being text-based and using fairly standard markup languages will hopefully facilitate the development of such applications.

The [Templar application](https://github.com/schulmar/Templar) is one application that allows the user to open and inspect the traces produced by Templight.

## Credits

The original version of Templight was created by Zoltán Borók-Nagy, Zoltán Porkoláb and József Mihalicza:
http://plc.inf.elte.hu/templight/




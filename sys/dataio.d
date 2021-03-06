/**
 * ae.sys.dataio
 *
 * License:
 *   This Source Code Form is subject to the terms of
 *   the Mozilla Public License, v. 2.0. If a copy of
 *   the MPL was not distributed with this file, You
 *   can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * Authors:
 *   Vladimir Panteleev <vladimir@thecybershadow.net>
 */

module ae.sys.dataio;

import std.exception : enforce;

import ae.sys.data;

// ************************************************************************

deprecated("std.stream is deprecated, use readFileData")
template readStreamData()
{
	static import std.stream;

	Data readStreamData(std.stream.Stream s)
	{
		auto size = s.size - s.position;
		assert(size < size_t.max);
		auto data = Data(cast(size_t)size);
		s.readExact(data.mptr, data.length);
		return data;
	}
}

// ************************************************************************

static import std.stdio;

Data readFileData(std.stdio.File f)
{
	Data result;
	auto size = f.size;
	if (size == ulong.max)
	{
		Data buf = Data(1024*1024);
		while (!f.eof())
			result ~= f.rawRead(cast(ubyte[])buf.mcontents);
		buf.deleteContents();
	}
	else
	{
		auto pos = f.tell;
		ulong remaining = size - pos;
		if (!remaining)
			return Data();
		enforce(remaining <= ulong(size_t.max), "File does not fit in memory");
		result = Data(cast(size_t)remaining);
		result.length = f.rawRead(cast(ubyte[])result.mcontents).length;
	}
	return result;
}

Data readData(string filename)
{
	auto f = std.stdio.File(filename, "rb");
	return readFileData(f);
}

// ************************************************************************

/// Wrapper for Data class, allowing an object to be swapped to disk
/// and automatically retreived as required.

final class SwappedData
{
	import std.file;
	import std.string;
	debug(SwappedData) import ae.sys.log;

private:
	Data _data;
	string fileName;
	const(char)* cFileName;

	static const MIN_SIZE = 4096; // minimum size to swap out

	debug(SwappedData) static Logger log;

public:
	this(string fileName)
	{
		debug(SwappedData) { if (log is null) log = new FileAndConsoleLogger("SwappedData"); log(fileName ~ " - Creating"); }
		this.fileName = fileName;
		cFileName = fileName.toStringz();
		if (exists(fileName))
			remove(fileName);
	}

	void unload()
	{
		if (!_data.empty && _data.length >= MIN_SIZE)
		{
			debug(SwappedData) log(fileName ~ " - Unloading");
			write(fileName, _data.contents);
			_data.clear();
		}
	}

	bool isLoaded()
	{
		return !exists(fileName);
	}

	// Getter
	Data data()
	{
		if (!_data.length)
		{
			debug(SwappedData) log(fileName ~ " - Reloading");
			if (!exists(fileName))
				return Data();
			_data = readData(fileName);
			remove(fileName);
		}
		return _data;
	}

	// Setter
	void data(Data data)
	{
		debug(SwappedData) log(fileName ~ " - Setting");
		if (exists(fileName))
			remove(fileName);
		_data = data;
	}

	size_t length()
	{
		if (!_data.empty)
			return _data.length;
		else
		if (exists(fileName))
			return cast(size_t)getSize(fileName);
		else
			return 0;
	}

	~this()
	{
		// Can't allocate in destructors.

		//debug(SwappedData) log(fileName ~ " - Destroying");
		/*if (exists(fileName))
		{
			debug(SwappedData) log(fileName ~ " - Deleting");
			remove(fileName);
		}*/
		import core.stdc.stdio : remove;
		remove(cFileName);
	}
}

module FITSIO

using Compat

export FITS,
       HDU,
       ImageHDU,
       TableHDU,
       ASCIITableHDU,
       FITSHeader,
       read_key,
       read_header,
       get_comment,
       set_comment!,
       copy_section

import Base: getindex,
             setindex!,
             length,
             show,
             read,
             write,
             close,
             ndims,
             size,
             endof,
             haskey,
             keys,
             values,
             start,
             next,
             done

# Libcfitsio submodule
include("libcfitsio.jl")

using .Libcfitsio

# There are a few direct `ccall`s to libcfitsio in this module. For this, we
# need a few non-exported things from Libcfitsio: the shared library handle,
# and a helper function for raising errors. TYPE_FROM_BITPIX is awkwardly
# defined in Libcfitsio, even though it is not used there.
import .Libcfitsio: libcfitsio,
                    fits_assert_ok,
                    TYPE_FROM_BITPIX

# HDU Types
abstract HDU

type ImageHDU <: HDU
    fitsfile::FITSFile
    ext::Int
end

type TableHDU <: HDU
    fitsfile::FITSFile
    ext::Int
end

type ASCIITableHDU <: HDU
    fitsfile::FITSFile
    ext::Int
end

# FITS
#
# The FITS type represents a FITS file. It holds a reference to a
# FITSFile object (basically the low-level CFITSIO pointer). It also
# holds a reference to all of the previously accessed HDU
# objects. This is so that only a single HDU object is created for
# each extension in the file. It also allows a FITS object to tell
# previously created HDUs about events that happen to the file, such
# as deleting extensions. This could be done by, e.g., setting ext=-1
# in the HDU object.
type FITS
    fitsfile::FITSFile
    filename::String
    mode::String
    hdus::Dict{Int, HDU}

    function FITS(filename::String, mode::String="r")
        f = (mode == "r"                     ? fits_open_file(filename, 0)   :
             mode == "r+" && isfile(filename)? fits_open_file(filename, 1)   :
             mode == "r+"                    ? fits_create_file(filename)    :
             mode == "w"                     ? fits_create_file("!"*filename):
             error("invalid open mode: $mode"))

        new(f, filename, mode, Dict{Int, HDU}())
    end
end

# FITSHeader
# 
# An in-memory representation of the header of an HDU. It stores the
# (key, value, comment) information for each card in a header. We
# could almost just use an OrderedDict for this, but we need to store
# comments.
type FITSHeader
    keys::Vector{ASCIIString}
    values::Vector{Any}
    comments::Vector{ASCIIString}
    map::Dict{ASCIIString, Int}

    function FITSHeader(keys::Vector{ASCIIString}, values::Vector,
                        comments::Vector{ASCIIString})
        if ((length(keys) != length(values)) ||
            (length(keys) != length(comments)))
            error("keys, values, comments must be same length")
        end
        map = [keys[i]=>i for i=1:length(keys)]
        new(keys, convert(Vector{Any}, values), comments, map)
    end
end

include("fits.jl")  # FITS methods
include("header.jl")  # FITSHeader methods
include("image.jl")  # ImageHDU methods
include("table.jl")  # TableHDU & ASCIITableHDU methods

function libcfitsio_version()
    # fits_get_version returns a float. e.g., 3.341f0. We parse that
    # into a proper version number. E.g., 3.341 -> v"3.34.1"
    v = convert(Int, round(1000 * fits_get_version()))
    x = div(v, 1000)
    y = div(rem(v, 1000), 10)
    z = rem(v, 10)
    VersionNumber(x, y, z)
end

include("deprecations.jl")

end # module

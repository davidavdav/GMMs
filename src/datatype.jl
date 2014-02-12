## datatype.jl Julia code to handle data on disc

require("gmmtypes.jl")

## constructor for a plain matrix.  rowvectors: data points x represented as rowvectors
function Data{T<:FloatingPoint}(x::Matrix{T}, rowvectors=true) 
    if rowvectors
        Data(T, Array{T,2}[x], nothing)
    else
        Data(T, Array{T,2}[x'], nothing)
    end
end

## constructor for a vector of plain matrices
function Data{T<:FloatingPoint}(x::Vector{Matrix{T}}, rowvectors=true)
    if rowvectors
        Data(T, x, nothing)
    else
        Data(T, map(transpose, x), nothing)
    end
end

## constructor for a plain file.
function Data(file::String, datatype::Type, read::Function)
    Data(datatype, [file], read)
end

## constructor for a vector of files
function Data{S<:String}(files::Vector{S}, datatype::Type, read::Function)
    Data(datatype, files, read)
end

kind(x::Data) = eltype(x.list) <: String ? :file : :matrix

function getindex(x::Data, i::Int) 
    if kind(x) == :matrix
        x.list[i]
    else
        x.read(x.list[i])
    end
end

## define an iterator for Data
Base.length(x::Data) = length(x.list)
Base.start(x::Data) = 0
Base.next(x::Data, state::Int) = x[state+1], state+1
Base.done(x::Data, state::Int) = state == length(x)

## stats: compute nth order stats for array
function stats{T<:FloatingPoint}(x::Array{T,2}, order::Int=2)
    n, d = size(x)
    res = [n]
    sx = zeros(order,d)
    for j=1:d
        for i=1:n
            xi = xp = x[i,j]
            sx[1,j] += xp
            for o=2:order
                xp *= xi
                sx[o,j] += xp
            end
        end
    end
    {n, map(i->vec(sx[i,:]), 1:order)...}
end

## this function calls pmap as an option for parallelism
function stats(d::Data, order::Int=2)
    s = pmap(stats, d)
    reduce(+, s)     
end

Base.sum(d::Data) = stats(d,1)[2]

function Base.mean(d::Data)
    n, sx = stats(d, 1)
    sx ./ n
end

function Base.var(d::Data)
    n, sx, sxx = stats(d, 2)
    μ = sx ./ n
    (sxx - n*μ.^2) ./ (n-1)
end

## this is potentially slow because it reads all file just to find out the size
function Base.size(d::Data)
    s = map(size, d)
    nrow, ncol = s[1]
    ok = true
    for i in 2:length(s)
        ok &= s[i][2] == ncol
        nrow += s[i][1]
    end
    if !ok
        error("Inconsistent number of columns in data")
    end
    nrow, ncol
end

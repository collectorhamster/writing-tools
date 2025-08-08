# writing-tools
Tools for academic writing.

## ["doi2LaTex"](https://github.com/collectorhamster/writing-tools/blob/main/doi2LaTex.jl): A Julia script that automatically generates LaTeX-formatted references from a list of DOIs.
How to use this script: 

1. Create a file named `doi.txt` and place it in the same directory as `doi2LaTeX.jl`.
2. Paste the desired DOIs into the file (typically one per line).
3. Run 
```bash
julia doi2LaTex.jl
```

and you will see a file called *"citfm.txt"*, which contains some LaTex codes. Copy and past these codes into your `*.tex` file, you can get references with standard format.

`HTTP.jl` and `JSON3.jl` are needed. `distributed.jl` should be installed because there are parallel processes. Please note that it is still recommended to check the format and correct it if necessary.

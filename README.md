# writing-tools
Tools for academic writing.

## ["doi2LaTex"](https://github.com/collectorhamster/writing-tools/blob/main/doi2LaTex.jl): A Julia script that automatically generates LaTeX-formatted references from a list of DOIs.
How to use this script: create file named *"doi.txt"* and past DOIs of references into it. Ensure that *"doi.txt"* and *"doi2LaTex.jl"* are in the same folder. Run 
```bash
julia doi2LaTex.jl
```
 and you will see a file called *"citfm.txt"*, which contains some LaTex codes. Copy and past these codes into your `*.tex` file, you can get references with standard format.

`HTTP.jl` and `JSON3.jl` are needed. `distributed.jl` should be installed because there are parallel processes. Please note that it is still recommended to check the format and correct it if necessary.

using Distributed
if nworkers() == 1
    addprocs(8)
end
@everywhere using HTTP, JSON3

@everywhere function get_journal_abbreviation(journal_name)
    # Dictionary of common journal abbreviations
    abbreviations = Dict(
        "Physical Review A" => "Phys. Rev. A",
        "Physical Review B" => "Phys. Rev. B",
        "Physical Review C" => "Phys. Rev. C",
        "Physical Review D" => "Phys. Rev. D",
        "Physical Review E" => "Phys. Rev. E",
        "Physical Review Letters" => "Phys. Rev. Lett.",
        "Physical Review X" => "Phys. Rev. X",
        "Physical Review Applied" => "Phys. Rev. Appl.",
        "Physical Review Materials" => "Phys. Rev. Mater.",
        "Physical Review Research" => "Phys. Rev. Res.",
        "Nature" => "Nature",
        "Science" => "Science",
        "Nature Physics" => "Nat. Phys.",
        "Nature Materials" => "Nat. Mater.",
        "Nature Communications" => "Nat. Commun.",
        "Scientific Reports" => "Sci. Rep.",
        "Applied Physics Letters" => "Appl. Phys. Lett.",
        "Journal of Applied Physics" => "J. Appl. Phys.",
        "Review of Scientific Instruments" => "Rev. Sci. Instrum.",
        "American Journal of Physics" => "Am. J. Phys.",
        "European Physical Journal B" => "Eur. Phys. J. B",
        "Journal of Physics: Condensed Matter" => "J. Phys.: Condens. Matter",
        "New Journal of Physics" => "New J. Phys.",
        "Proceedings of the National Academy of Sciences" => "Proc. Natl. Acad. Sci.",
        "Journal of the American Chemical Society" => "J. Am. Chem. Soc.",
        "Angewandte Chemie International Edition" => "Angew. Chem. Int. Ed.",
        "Chemical Reviews" => "Chem. Rev.",
        "Advanced Materials" => "Adv. Mater.",
        "Nano Letters" => "Nano Lett.",
        "ACS Nano" => "ACS Nano"
    )
    
    # Return abbreviation if found, otherwise return the original name
    return get(abbreviations, journal_name, journal_name)
end

# function get_doi_info(doi_url)
#     # Clean the DOI
#     doi = replace(doi_url, "https://doi.org/" => "")
    
#     # Check if it's an ArXiv paper
#     if occursin("arXiv", doi) || occursin("arxiv", doi)
#         return get_arxiv_info(doi)
#     else
#         return get_crossref_info(doi)
#     end
# end

####### supported function for literaturs on arXiv.org
@everywhere function extract_xml_content(xml_string, tag)
    pattern = Regex("<$(tag)>(.*?)</$(tag)>", "s")
    match_result = match(pattern, xml_string)
    if match_result !== nothing
        content = match_result.captures[1]
        return strip(replace(content, r"\s+" => " "))
    end
    return "Unknown"
end

@everywhere function extract_arxiv_authors(xml_content)
    authors = []
    author_pattern = r"<author>\s*<name>(.*?)</name>"
    for m in eachmatch(author_pattern, xml_content)
        author_name = strip(m.captures[1])
        push!(authors, author_name)
    end
    return authors
end

########### information of literaturs on arXiv.org
@everywhere function get_arxiv_info(doi)
    # Extract ArXiv ID from DOI
    arxiv_id = ""
    if occursin("arXiv.", doi)
        arxiv_id = split(doi, "arXiv.")[2]
    elseif occursin("arxiv.", doi)
        arxiv_id = split(doi, "arxiv.")[2]
    end
    
    try
        # Use ArXiv API
        arxiv_url = "http://export.arxiv.org/api/query?id_list=$(arxiv_id)"
        response = HTTP.get(arxiv_url)
        xml_content = String(response.body)
        
        # Parse basic info from XML
        title = extract_xml_content(xml_content, "title")
        authors = extract_arxiv_authors(xml_content)
        published = extract_xml_content(xml_content, "published")
        
        # Extract year from published date
        year = "Unknown"
        if published != "Unknown"
            year_match = match(r"(\d{4})", published)
            if year_match !== nothing
                year = year_match.captures[1]
            end
        end
        
        return Dict(
            "first_author_given_name" => length(authors) > 0 ? split(authors[1], " ")[1] : "Unknown",
            "authors" => authors,
            "url" => "https://arxiv.org/abs/$(arxiv_id)",
            "title" => title,
            "published_year" => year,
            "arxiv_id" => "arXiv.$(arxiv_id)"
        )
        
    catch e
        println("Error fetching ArXiv info: $e")
        return nothing
    end
end

########### information of pulished literatures
@everywhere function get_crossref_info(doi)
    # Clean the DOI
    # doi = replace(doi_url, "https://doi.org/" => "")
    
    try
        response = HTTP.get("https://api.crossref.org/works/$(doi)")
        work = JSON3.parse(String(response.body))["message"]
        
        # Extract authors
        authors = []
        first_author_given_name = "Unknown"
        if haskey(work, "author")
            for author in work["author"]
                if haskey(author, "given") && haskey(author, "family")
                    push!(authors, "$(author["given"]) $(author["family"])")
                elseif haskey(author, "name")
                    push!(authors, author["name"])
                elseif haskey(author, "family")
                    push!(authors, author["family"])
                end
            end
            # Get first author's given name only
            if haskey(work["author"][1], "family")
                first_author_given_name = work["author"][1]["family"]
            end
        end
        
        # Extract publication year
        year = "Unknown"
        if haskey(work, "published") && haskey(work["published"], "date-parts")
            date_parts = work["published"]["date-parts"][1]
            if !isempty(date_parts)
                year = string(date_parts[1])
            end
        end
        
        # Extract first page
        first_page = "Unknown"
        if haskey(work, "page")
            page_info = work["page"]
            if occursin("-", page_info)
                first_page = split(page_info, "-")[1]
            else
                first_page = page_info
            end
        end
        
        # Get journal name and abbreviation
        journal_full = get(work, "container-title", ["Unknown"])[1]
        journal_abbrev = get_journal_abbreviation(journal_full)
        
        url = "https://doi.org/$(get(work, "DOI", doi))"

        return Dict(
            "title" => get(work, "title", ["Unknown"])[1],
            # "journal" => journal_full,
            "journal_abbrev" => journal_abbrev,
            "volume" => get(work, "volume", "Unknown"),
            "article_number" => get(work, "article-number", "Unknown"),
            "pages" => get(work, "page", "Unknown"),
            "first_page" => first_page,
            "published_year" => year,
            "authors" => authors,
            "first_author_given_name" => first_author_given_name,
            "url" => url
        )
        
    catch e
        println("Error: $e")
        return nothing
    end
end

##### use information to generate standard form
@everywhere function citLaTex(doi_url)
    doi = replace(doi_url, "https://doi.org/" => "")
    # Check if it's an ArXiv paper
    if occursin("arXiv", doi) || occursin("arxiv", doi)
        info = get_arxiv_info(doi)
        citnm = info["first_author_given_name"]*info["published_year"]
        authors = info["authors"]
        if length(authors) > 8
            authors_join = join(authors[1:3], ", ")
            authors_join = authors_join*" .etc"
        else
            authors_join = join(authors, ", ")
        end
        title = info["title"]
        url = info["url"]
        journal = info["arxiv_id"]
        year = info["published_year"]
        return "\\bibitem{$(citnm)} $(authors_join), $(title), \\href{$(url)}{$(journal).}"
    else
        info = get_crossref_info(doi)
        citnm = info["first_author_given_name"]*info["published_year"]
        authors = info["authors"]
        if length(authors) > 8
            authors_join = join(authors[1:3], ", ")
            authors_join = authors_join*" .etc"
        else
            authors_join = join(authors, ", ")
        end
        title = info["title"]
        url = info["url"]
        journal = info["journal_abbrev"]
        vol = info["volume"]
        if info["article_number"] != "Unknown"
            art_num = info["article_number"]
        else
            art_num = info["pages"]
        end
        year = info["published_year"]
        return "\\bibitem{$(citnm)} $(authors_join), $(title), \\href{$(url)}{$(journal). {\\bf $(vol)}, $(art_num), ($(year)).}"
    end
    
    return str
end

######### test
# doi = "10.1103/PhysRevLett.42.673"
# doi = "10.48550/arXiv.2409.17251"
# get_crossref_info(doi)
# get_arxiv_info(doi)
# citLaTex(doi)

######## read the doi.txt file, generate standard form and save as citnm.txt
# path = "/Users/jinyuanshang/Nutstore Files/file_numerical/Qausicrystal_trans/LaTex_works/manuscript/"
path =""
doi_arr = readlines(path*"doi.txt")
doi_arr = filter(!isempty, doi_arr)

anw = @sync @distributed (vcat) for n in eachindex(doi_arr)
    citLaTex(doi_arr[n])
end
combined = join(anw,"\n\n")
open(path*"citfm.txt", "w") do file
    write(file, combined)
end
println("done.")

rmprocs(workers())
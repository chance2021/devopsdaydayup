text = """
Bash is the GNU Project's shell—the Bourne Again SHell. This is an sh-compatible shell that incorporates useful features from the Korn shell (ksh) and the C shell (csh). It is intended to conform to the IEEE POSIX P1003.2/ISO 9945.2 Shell and Tools standard. It offers functional improvements over sh for both programming and interactive use. In addition, most sh scripts can be run by Bash without modification.
"""

words = text.replace(",", " ").replace(".", " ").split()
print(words)

words_dict = {}

for w in words:
    words_dict[w] = words.count(w)

for w in set(words):
    print(f"There are {words_dict[w]} {w} in the text")
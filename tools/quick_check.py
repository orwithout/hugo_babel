# quick_check.py
import rdflib, sys, re
from rdflib.namespace import SKOS

g = rdflib.Graph()
g.parse(sys.argv[1], format="turtle")
print("Triples:", len(g))
num_codes = [
    str(l) for _, _, l in g.triples((None, SKOS.notation, None))
    if re.match(r'^\d+(\.\d+)*$', str(l))
]
print("Numeric concepts:", len(num_codes))
print("Sample codes:", num_codes[:15])

# make_udc_yaml.py
import rdflib, yaml, sys, re
from rdflib.namespace import SKOS

PAT_NUM = re.compile(r'^\d+(\.\d+)*$')

def extract(ttl, lang):
    g = rdflib.Graph(); g.parse(ttl, format="turtle")
    out = {}
    for s, _, lit in g.triples((None, SKOS.notation, None)):
        code = str(lit)
        if not PAT_NUM.match(code): continue
        label = next((l for l in g.objects(s, SKOS.prefLabel)
                      if (l.language or '') == lang), None)
        if label: out[code] = str(label)
    return out

ttl = "udcs-skos.ttl"
for lg in ("en", "zh"):
    d = extract(ttl, lg)
    with open(f"data/udc/{lg}.yaml", "w", encoding="utf-8") as f:
        yaml.dump(d, f, allow_unicode=True)

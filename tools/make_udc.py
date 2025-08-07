import argparse, re
from pathlib import Path
import rdflib
from rdflib.namespace import SKOS

PAT_NUM = re.compile(r'^\d+(?:\.\d+)*$')

def safe(txt): return re.sub(r'[\\/:"*?<>|]', '_', txt)

def load_labels(rdf_file, lang):
    g = rdflib.Graph()
    g.parse(rdf_file, format="turtle")
    concepts = {}
    for s, _, lit in g.triples((None, SKOS.notation, None)):
        code = str(lit)
        if not PAT_NUM.match(code): continue
        # 找指定语言的 prefLabel
        labels = list(g.objects(s, SKOS.prefLabel))
        lbl = code
        if labels:
            # 优先 lang，其次英文，其后随便
            lbl_by_lang = next((l for l in labels if l.language == lang), None)
            lbl_en      = next((l for l in labels if l.language == 'en'), None)
            lbl         = str(lbl_by_lang or lbl_en or labels[0])
        concepts[code] = lbl
    return concepts

def ensure_parent(code, codes):
    if '.' in code:
        p = code.rsplit('.',1)[0]
    elif len(code)>1:
        p = code[:-1]
    else:
        return None
    return p if p in codes else ensure_parent(p, codes)

def build_tree(codes):
    tree={}
    for c in codes:
        p = ensure_parent(c, codes)
        tree.setdefault(p,[]).append(c)
    return tree

def make_dirs(root, code, labels, tree):
    if code is not None:
        name = f"{safe(code)}_{safe(labels[code])}"
        root = root/name
        root.mkdir(exist_ok=True)
        (root/"_label.txt").write_text(labels[code],"utf-8")
    for child in sorted(tree.get(code,[]), key=lambda x: [len(x),x]):
        make_dirs(root,child,labels,tree)

def main():
    p = argparse.ArgumentParser()
    p.add_argument("rdf_file")
    p.add_argument("out_dir")
    p.add_argument("--lang","-l",default="en",
                   help="choose skos label language (e.g. en, zh, fi, sv)")
    args = p.parse_args()

    labels = load_labels(args.rdf_file, args.lang)
    tree   = build_tree(labels.keys())
    out    = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)
    make_dirs(out, None, labels, tree)
    print(f"✅ 以语言 {args.lang} 生成 {len(labels)} 个目录到 {out.resolve()}")

if __name__=="__main__":
    main()

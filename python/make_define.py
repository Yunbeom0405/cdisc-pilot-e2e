"""Build Define-XML 2.1 from the spec workbook and the XPT headers.

Usage: python python/make_define.py sdtm|adam
Writes define/<kind>/define.xml. Lengths and display formats come from the XPT
files; everything else comes from specs/<kind>-spec.xlsx.
"""
import re
import struct
import sys
from datetime import datetime
from pathlib import Path
from xml.etree import ElementTree as ET

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
ODM, DEF, XLINK = "http://www.cdisc.org/ns/odm/v1.3", "http://www.cdisc.org/ns/def/v2.1", "http://www.w3.org/1999/xlink"
ET.register_namespace("", ODM)
ET.register_namespace("def", DEF)
ET.register_namespace("xlink", XLINK)


def q(tag):
    ns, _, name = tag.partition(":")
    return "{%s}%s" % ({"": ODM, "d": DEF, "x": XLINK}[ns if name else ""], name or ns)


def A(**kw):
    """attribute dict with d__/x__ prefixes mapped to namespaced names"""
    out = {}
    for k, v in kw.items():
        if v is None:
            continue
        p, _, n = k.partition("__")
        out[q(p + ":" + n) if n else k] = str(v)
    return out


def add(parent, tag, text=None, **kw):
    el = ET.SubElement(parent, q(tag), A(**kw))
    if text:
        el.text = text
    return el


def desc(parent, text):
    d = ET.SubElement(parent, q("Description"))
    t = ET.SubElement(d, q("TranslatedText"))
    t.set("{http://www.w3.org/XML/1998/namespace}lang", "en")
    t.text = text
    return d


def read_xpt(path):
    """name -> (type, length, format) in column order, from a v5 transport file"""
    b = path.read_bytes()
    i = b.index(b"NAMESTR HEADER RECORD")
    n = int(b[i + 34:i + 38])
    start = i - 20 + 80
    out = {}
    for k in range(n):
        ntype, _, nlng, _ = struct.unpack(">hhhh", b[start + k * 140:start + k * 140 + 8])
        rec = b[start + k * 140 + 8:start + k * 140 + 140]
        name, label, form = (rec[:8].decode().strip(), rec[8:48].decode().strip(), rec[48:56].decode().strip())
        out[name] = ("text" if ntype == 2 else "num", nlng, form, label)
    return out


def rows(wb, sheet):
    it = wb[sheet].values
    head = next(it)
    return [dict(zip(head, r)) for r in it if any(c is not None for c in r)]


def clean(v):
    return None if v is None or str(v).strip() == "" else str(v).strip()


def where_parts(wc):
    m = re.match(r"^(\w+) (EQ|IN) (.+)$", wc)
    var, comp, val = m.groups()
    vals = [x.strip() for x in val.strip("()").split(",")] if comp == "IN" else [val]
    return var, comp, vals


def oid(s):
    return re.sub(r"[^A-Za-z0-9_.]+", "_", s).strip("_")


def build(kind):
    wb = openpyxl.load_workbook(ROOT / "specs" / f"{kind}-spec.xlsx", read_only=True)
    study = {r["Attribute"]: r["Value"] for r in rows(wb, "Study")}
    stds = rows(wb, "Standards")
    datasets, variables, vlevel = rows(wb, "Datasets"), rows(wb, "Variables"), rows(wb, "ValueLevel")
    codelists, methods, comments, docs = rows(wb, "Codelists"), rows(wb, "Methods"), rows(wb, "Comments"), rows(wb, "Documents")
    xpt_dir = ROOT / "data" / "derived" / kind
    sdtm = kind == "sdtm"

    odm = ET.Element(q("ODM"), {"ODMVersion": "1.3.2", "FileType": "Snapshot", "FileOID": f"define.{kind}",
                                "CreationDateTime": datetime.now().strftime("%Y-%m-%dT%H:%M:%S"),
                                "Originator": "P1 portfolio", "SourceSystem": "make_define.py",
                                "SourceSystemVersion": "1.0"})
    st = add(odm, "Study", OID=study["StudyName"])
    g = add(st, "GlobalVariables")
    add(g, "StudyName", study["StudyName"])
    add(g, "StudyDescription", study["StudyDescription"])
    add(g, "ProtocolName", study["ProtocolName"])
    mdv = add(st, "MetaDataVersion", OID=f"MDV.{kind.upper()}", Name=f"{study['StudyName']} {kind.upper()}",
              Description=f"{study['StudyName']} {kind.upper()} metadata",
              d__DefineVersion="2.1.0")

    ds_std = {"SDTMIG 3.4": "STD.SDTMIG", "ADaMIG 1.3": "STD.ADAMIG", "OCCDS 1.1": "STD.OCCDS"}
    std_el = add(mdv, "d:Standards")
    for s in stds:
        add(std_el, "d:Standard", OID=s["OID"], Name=s["Name"], Type=s["Type"], PublishingSet=clean(s["Publishing Set"]),
            Version=s["Version"], Status=s["Status"])
    std_ct = {}
    for s in stds:
        if s["Type"] == "CT":
            std_ct[s["Version"]] = s["OID"]
    for d in docs:
        a = add(mdv, "d:AnnotatedCRF")
        add(a, "d:DocumentRef", leafID=f"LF.{d['ID']}")

    # value-level metadata
    vl_by_var = {}
    for r in vlevel:
        vl_by_var.setdefault((r["Dataset"], r["Variable"]), []).append(r)
    wc_seen = {}
    vl_items = []
    for (ds, var), lst in vl_by_var.items():
        vl = add(mdv, "d:ValueListDef", OID=f"VL.{ds}.{var}")
        for n, r in enumerate(lst, 1):
            w_var, comp, vals = where_parts(r["Where Clause"])
            item_oid = f"IT.{ds}.{var}.{oid(w_var + '.' + '.'.join(vals))}"
            ir = add(vl, "ItemRef", ItemOID=item_oid, OrderNumber=n, Mandatory="No",
                     MethodOID=clean(r["Method"]))
            wc_oid = f"WC.{ds}.{var}.{oid(w_var + '.' + comp + '.' + '.'.join(vals))}"
            add(ir, "d:WhereClauseRef", WhereClauseOID=wc_oid)
            if wc_oid not in wc_seen:
                wc_seen[wc_oid] = (ds, w_var, comp, vals)
            vl_items.append((item_oid, var, r))
    for wc_oid, (ds, w_var, comp, vals) in wc_seen.items():
        wc = add(mdv, "d:WhereClauseDef", OID=wc_oid)
        rc = add(wc, "RangeCheck", SoftHard="Soft", d__ItemOID=f"IT.{ds}.{w_var}", Comparator=comp)
        for v in vals:
            add(rc, "CheckValue", v)

    # datasets
    var_by_ds = {}
    for v in variables:
        var_by_ds.setdefault(v["Dataset"], []).append(v)
    items = {}
    problems = []
    leaves = []
    for d in datasets:
        name = d["Dataset"]
        xpt = read_xpt(xpt_dir / f"{name.lower()}.xpt")
        spec_vars = sorted(var_by_ds[name], key=lambda v: int(v["Order"]))
        if [v["Variable"] for v in spec_vars] != list(xpt):
            problems.append(f"{name}: spec and xpt variables differ: "
                            f"{set(v['Variable'] for v in spec_vars) ^ set(xpt)}")
            continue
        keys = [k.strip() for k in (d["Key Variables"] or "").split(",")]
        ig = add(mdv, "ItemGroupDef", OID=f"IG.{name}", Name=name, Repeating="No" if name == "DM" or not sdtm and name == "ADSL" else "Yes",
                 IsReferenceData="No" if sdtm else None, SASDatasetName=name, Purpose=d["Purpose"],
                 d__Structure=d["Structure"], d__ArchiveLocationID=f"LF.{name}",
                 d__CommentOID=clean(d["Comment"]), d__StandardOID=ds_std[d["Standard"]])
        desc(ig, d["Description"])
        for v in spec_vars:
            var = v["Variable"]
            ir = add(ig, "ItemRef", ItemOID=f"IT.{name}.{var}", OrderNumber=v["Order"],
                     Mandatory=v["Mandatory"], KeySequence=keys.index(var) + 1 if var in keys else None,
                     MethodOID=clean(v["Method"]), Role=v["Role"] if sdtm else None)
            t, length, form, _ = xpt[var]
            items[f"IT.{name}.{var}"] = (name, var, v, t, length, form)
        add(ig, "d:Class", Name=d["Class"])
        leaves.append((f"LF.{name}", f"{name.lower()}.xpt", f"{name.lower()}.xpt"))
    if problems:
        sys.exit("\n".join(problems))

    def itemdef(item_oid, name, var, spec, t, length, form, vl_ref=None, assigned=None):
        dt = spec["Data Type"]
        if t == "num" and dt == "text":
            dt = "float"
        elif t == "num" and dt in ("date", "datetime"):
            dt = "integer"  # SAS date/datetime is a number; Define date types are ISO text
        it = add(mdv, "ItemDef", OID=item_oid, Name=var, SASFieldName=var,
                 DataType=dt, Length=length if (t == "text" or dt in ("integer", "float", "date")) else None,
                 d__DisplayFormat=form or None, d__CommentOID=clean(spec.get("Comment")))
        desc(it, spec.get("Label") or spec["Variable"])
        if clean(spec.get("Codelist")):
            add(it, "CodeListRef", CodeListOID=f"CL.{spec['Codelist']}")
        origin = spec["Origin"]
        o = add(it, "d:Origin", Type=origin, Source=spec["Source"] if origin == "Collected" else None)
        pages = clean(spec.get("Pages"))
        if pages:
            dr = add(o, "d:DocumentRef", leafID="LF.ACRF")
            add(dr, "d:PDFPageRef", Type="PhysicalRef", PageRefs=pages)
        if origin == "Predecessor" and clean(spec.get("Developer Notes")):
            desc(o, spec["Developer Notes"])
        if vl_ref:
            add(it, "d:ValueListRef", ValueListOID=vl_ref)
        return it

    # ItemDefs are written after ItemGroupDefs; keep ODM element order
    for item_oid, (name, var, spec, t, length, form) in items.items():
        itemdef(item_oid, name, var, spec, t, length, form,
                vl_ref=f"VL.{name}.{var}" if (name, var) in vl_by_var else None)
    for item_oid, var, r in vl_items:
        ds = item_oid.split(".")[1]
        _, _, spec, t, length, form = items[f"IT.{ds}.{var}"]
        vspec = {"Data Type": r["Data Type"], "Label": spec["Label"], "Variable": var, "Codelist": r["Codelist"],
                 "Origin": r["Origin"], "Source": r["Source"] or "Sponsor", "Pages": r["Pages"],
                 "Developer Notes": r["Developer Notes"]}
        if r["Length"]:
            length = r["Length"]
        itemdef(item_oid, ds, item_oid.replace(f"IT.{ds}.", ""), vspec, t, length, form)

    # codelists
    cls = {}
    for r in codelists:
        cls.setdefault(r["ID"], []).append(r)
    for cid, terms in cls.items():
        h = terms[0]
        term_src = h["Terminology"]
        ver = re.search(r"\d{4}-\d{2}-\d{2}", term_src or "")
        nci = term_src and term_src.startswith("CDISC/NCI")
        std = None
        if nci and ver:
            std = std_ct.get(ver.group(0))
        cl = add(mdv, "CodeList", OID=f"CL.{cid}", Name=h["Name"], DataType=h["Data Type"],
                 d__StandardOID=std, d__IsNonStandard="Yes" if not nci else None)
        decoded = any(clean(t["Decoded Value"]) for t in terms)
        for t in sorted(terms, key=lambda t: int(t["Order"])):
            ext = "Yes" if nci and not clean(t["NCI Term Code"]) else None
            if decoded:
                ci = add(cl, "CodeListItem", CodedValue=str(t["Term"]), d__ExtendedValue=ext)
                dc = add(ci, "Decode")
                tt = ET.SubElement(dc, q("TranslatedText"))
                tt.set("{http://www.w3.org/XML/1998/namespace}lang", "en")
                tt.text = clean(t["Decoded Value"]) or str(t["Term"])
            else:
                ci = add(cl, "EnumeratedItem", CodedValue=str(t["Term"]), d__ExtendedValue=ext)
            if clean(t["NCI Term Code"]):
                add(ci, "Alias", Context="nci:ExtCodeID", Name=t["NCI Term Code"])
        if clean(h["NCI Codelist Code"]):
            add(cl, "Alias", Context="nci:ExtCodeID", Name=h["NCI Codelist Code"])

    for m in methods:
        md = add(mdv, "MethodDef", OID=m["ID"], Name=m["ID"], Type="Computation" if m["Type"] == "Algorithm" else "Other")
        desc(md, m["Description"])
    for c in comments:
        cd = add(mdv, "d:CommentDef", OID=c["ID"])
        desc(cd, c["Description"])
    leaves += [(f"LF.{d['ID']}", d["Href"], d["Title"]) for d in docs]
    for lid, href, title in leaves:
        add(add(mdv, "d:leaf", ID=lid, x__href=href), "d:title", title)
    return odm


def main():
    kind = sys.argv[1]
    odm = build(kind)
    ET.indent(odm)
    out = ROOT / "define" / kind / "define.xml"
    out.parent.mkdir(parents=True, exist_ok=True)
    body = ET.tostring(odm, encoding="unicode")
    out.write_text('<?xml version="1.0" encoding="UTF-8"?>\n<?xml-stylesheet type="text/xsl" href="../define2-1-0.xsl"?>\n' + body + "\n",
                   encoding="utf-8")
    print(out, len(body))


if __name__ == "__main__":
    main()

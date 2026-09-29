# mapper.py : turn an affine schedule from ISL into PE coordinates
import islpy as isl
import json


def extract_coords(domain, schedule):
    """
    domain  : ISL set of loop iterations
    schedule: ISL map (i,j,k)->(t,x,y)
    returns list of ((i,j,k), (t,x,y)) tuples
    """
    points = []
    iters = domain.sample_params().get_set_list()
    for s in iters:
        p = schedule.apply(isl.Map.from_domain_and_range(s, s))
        coords = p.range().tuple_name()
        points.append((s, coords))
    return points


def emit_netlist(points, mesh_dim):
    """
    points : list from extract_coords
    mesh_dim: (rows,cols)
    """
    netlist = {"rows": mesh_dim[0], "cols": mesh_dim[1], "pes": []}
    for it, (t, x, y) in points:
        netlist["pes"].append({"time": t, "row": x, "col": y})
    with open("netlist.json", "w") as f:
        json.dump(netlist, f, indent=2)


# Load ISL objects from a JSON schedule produced by Polly/Tiramisu …

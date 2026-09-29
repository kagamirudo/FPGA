// mesh_top.sv
module mesh_top #(
    parameter N = 4,  // rows
    parameter M = 4,  // columns
    parameter WIDTH = 32
)(
    input  logic                       aclk,
    input  logic                       aresetn,
    // AXI-Stream system input/output
    input  logic [WIDTH-1:0]           sys_in_tdata,
    input  logic                       sys_in_tvalid,
    output logic                       sys_in_tready,
    output logic [WIDTH-1:0]           sys_out_tdata,
    output logic                       sys_out_tvalid,
    input  logic                       sys_out_tready
);
    // Internal wiring arrays
    logic [N:0][M-1:0][WIDTH-1:0]      north_south_data;
    logic [N:0][M-1:0]                 north_south_valid, north_south_ready;
    logic [N-1:0][M:0][WIDTH-1:0]      west_east_data;
    logic [N-1:0][M:0]                 west_east_valid,  west_east_ready;

    // Connect system input to north edge row 0
    assign north_south_data[0][0]   = sys_in_tdata;
    assign north_south_valid[0][0]  = sys_in_tvalid;
    assign sys_in_tready            = north_south_ready[0][0];

    // Loop to instantiate PEs
    genvar r,c;
    generate
        for (r=0; r<N; r++) begin : row
            for (c=0; c<M; c++) begin : col
                pe_mac_axis #(.WIDTH(WIDTH)) PE (
                    .aclk        (aclk),
                    .aresetn     (aresetn),
                    // North / South
                    .n_tdata     (north_south_data[r][c]),
                    .n_tvalid    (north_south_valid[r][c]),
                    .n_tready    (north_south_ready[r][c]),
                    .s_tdata     (north_south_data[r+1][c]),
                    .s_tvalid    (north_south_valid[r+1][c]),
                    .s_tready    (north_south_ready[r+1][c]),
                    // West / East
                    .w_tdata     (west_east_data[r][c]),
                    .w_tvalid    (west_east_valid[r][c]),
                    .w_tready    (west_east_ready[r][c]),
                    .e_tdata     (west_east_data[r][c+1]),
                    .e_tvalid    (west_east_valid[r][c+1]),
                    .e_tready    (west_east_ready[r][c+1]),
                    // No run-time config in this toy example
                    .cfg_tdata   ('0), .cfg_tvalid(1'b0), .cfg_tready()
                );
            end
        end
    endgenerate

    // Hook east edge of last column to system output
    assign sys_out_tdata  = west_east_data[0][M];
    assign sys_out_tvalid = west_east_valid[0][M];
    assign west_east_ready[0][M] = sys_out_tready;
endmodule

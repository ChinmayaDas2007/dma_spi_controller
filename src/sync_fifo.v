module sync_fifo #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH = 16
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    write_en,
    input  wire                    read_en,
    input  wire [DATA_WIDTH-1:0]   data_in,
    output reg  [DATA_WIDTH-1:0]   data_out,
    output wire                    empty,
    output wire                    full
);

    localparam PTR_WIDTH = 4; 

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    assign empty = (wr_ptr == rd_ptr);
    assign full  = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) && 
                   (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (write_en && !full) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in;
            wr_ptr <= wr_ptr + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            data_out <= 0;
        end else if (read_en && !empty) begin
            data_out <= mem[rd_ptr[PTR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1;
        end
    end

endmodule
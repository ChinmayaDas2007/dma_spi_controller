module sync_fifo #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH = 16
)(
    input  wire                    clk,       // Main system clock
    input  wire                    rst_n,     // Active-low reset (clears everything)
    input  wire                    write_en,  // CPU says "I want to write"   ||| write enable line 
    input  wire                    read_en,   // SPI engine says "I want to read"  |||  read enable line
    input  wire [DATA_WIDTH-1:0]   data_in,   // 16-bit data coming from CPU
    output reg  [DATA_WIDTH-1:0]   data_out,  // 16-bit data going to SPI engine
    output wire                    empty,     // Flag telling SPI "stop reading"
    output wire                    full       // Flag telling CPU "stop writing"
);

    // PTR_WIDTH is 4 (because 2^4 = 16 addresses).
    localparam PTR_WIDTH = 4; 

    // The actual physical memory: 16 slots, each 16 bits wide.
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers are 5 bits wide [4:0] for the wrap-around trick.
    reg [PTR_WIDTH:0] wr_ptr;
    reg [PTR_WIDTH:0] rd_ptr;

    // --- COMBINATIONAL LOGIC (Updates instantly) ---
    // Empty when all 5 bits of both pointers are identical.
    assign empty = (wr_ptr == rd_ptr);
    
    // Full when the top bit is different, but the bottom 4 bits are the same.
    assign full  = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) && 
                   (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);

    // --- SEQUENTIAL LOGIC (Updates only on the clock tick) ---
    
    // Write Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0; // On reset, point to address 0
        end else if (write_en && !full) begin
            mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in; // Store data
            wr_ptr <= wr_ptr + 1;                  // Move pointer forward
        end
    end

    // Read Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            data_out <= 0;
        end else if (read_en && !empty) begin
            data_out <= mem[rd_ptr[PTR_WIDTH-1:0]]; // Output data
            rd_ptr <= rd_ptr + 1;                   // Move pointer forward
        end
    end

endmodule

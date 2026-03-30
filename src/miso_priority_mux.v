module miso_priority_mux (
    input  wire [2:0] slave_select, // 3-bit signal (e.g., from master decoding)
    input  wire       miso_s1,      // MISO line from Slave 1
    input  wire       miso_s2,      // MISO line from Slave 2
    input  wire       miso_s3,      // MISO line from Slave 3
    output reg        miso_out      // The single wire going into the Master core
);

    // This is a basic priority multiplexer as described in the RTL analysis
    always @(*) begin
        case (slave_select)
            3'b001:  miso_out = miso_s1; // Connect Slave 1
            3'b010:  miso_out = miso_s2; // Connect Slave 2
            3'b100:  miso_out = miso_s3; // Connect Slave 3
            default: miso_out = 1'b0;    // Tie to 0 if no slave is selected
        endcase
    end

endmodule
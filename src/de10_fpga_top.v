module de10_fpga_top (
    input  wire        CLOCK_50,  // 50 MHz clock from DE10
    input  wire [3:0]  KEY,       // Push buttons (Active Low)
    input  wire [9:0]  SW,        // Slide switches
    output wire [9:0]  LEDR,      // Red LEDs
    inout  wire [35:0] GPIO       // Expansion Header
);

    // --- SYSTEM SIGNALS ---
    wire rst_n = KEY[0];          // Button 0 is Reset
    wire trigger_btn = ~KEY[1];   // Button 1 is our Burst Trigger (inverted to active-high)
    
    // --- EDGE DETECTOR FOR BUTTON ---
    reg trigger_d1, trigger_d2;
    wire burst_start = trigger_d1 & ~trigger_d2; // 1-clock-cycle pulse when pressed
    
    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            trigger_d1 <= 0;
            trigger_d2 <= 0;
        end else begin
            trigger_d1 <= trigger_btn;
            trigger_d2 <= trigger_d1;
        end
    end

    // --- BURST WRITE FSM ---
    reg [1:0] state;
    reg wr_en;
    reg [31:0] wr_data;
    
    always @(posedge CLOCK_50 or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            wr_en <= 0;
            wr_data <= 0;
        end else begin
            wr_en <= 0; // Default off
            case (state)
                0: if (burst_start) state <= 1; // Wait for button press
                1: begin wr_en <= 1; wr_data <= 32'hAAAA_BBBB; state <= 2; end // Word 1
                2: begin wr_en <= 1; wr_data <= 32'h5555_1111; state <= 3; end // Word 2
                3: begin wr_en <= 1; wr_data <= 32'h1234_5678; state <= 0; end // Word 3
            endcase
        end
    end

    // --- INSTANTIATE YOUR ARCHITECTURE ---
    wire tx_full;
    wire sclk_out, mosi_out;
    wire [2:0] ss_n_out;
    
    spi_top dma_spi_core (
        .clk(CLOCK_50),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .tx_full(tx_full),
        .sclk(sclk_out),
        .mosi(mosi_out),
        .miso_s1(GPIO[3]), // MISO connected to GPIO pin 3
        .miso_s2(1'b0),
        .miso_s3(1'b0),
        .ss_n(ss_n_out),
        .slave_sel(3'b001), // Hardcoded to target Slave 1
        .cpol(SW[0]),       // Switch 0 controls Clock Polarity
        .cpha(SW[1]),       // Switch 1 controls Clock Phase
        .clk_div(16'd4)     // Divide 50MHz by 4 = 12.5MHz SPI Clock
    );

    // --- MAP TO PHYSICAL PINS ---
    // Output SPI signals to the GPIO header so you can probe them
    assign GPIO[0] = sclk_out;
    assign GPIO[1] = mosi_out;
    assign GPIO[2] = ss_n_out[0];
    
    // Map status to LEDs
    assign LEDR[0] = tx_full;      // LED 0 shows if FIFO is full
    assign LEDR[9] = ~rst_n;       // LED 9 shows if board is in reset

endmodule
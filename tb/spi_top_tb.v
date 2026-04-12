`timescale 1ns / 1ps

module spi_top_tb;

    // System Signals
    reg        clk;
    reg        rst_n;
    
    // CPU Interface
    reg        wr_en;
    reg [31:0] wr_data;     // UPGRADED to 32-bit
    wire       tx_full;
    
    // SPI Physical Pins
    wire       sclk;
    wire       mosi;
    reg        miso_s1;
    reg        miso_s2;
    reg        miso_s3;
    wire [2:0] ss_n;
    
    // Configuration
    reg [2:0]  slave_sel;
    reg        cpol;
    reg        cpha;
    reg [15:0] clk_div;

    // Instantiate the Top Level Design (The Whole Chip)
    spi_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .wr_data(wr_data),
        .tx_full(tx_full),
        .sclk(sclk),
        .mosi(mosi),
        .miso_s1(miso_s1),
        .miso_s2(miso_s2),
        .miso_s3(miso_s3),
        .ss_n(ss_n),
        .slave_sel(slave_sel),
        .cpol(cpol),
        .cpha(cpha),
        .clk_div(clk_div)
    );

    // 1. Generate Fast System Clock (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 2. Dummy Slaves (just to keep MISO lines from floating)
    initial begin
        miso_s1 = 0; miso_s2 = 0; miso_s3 = 0;
    end
    always @(negedge sclk) miso_s1 <= ~miso_s1; // Slave 1 responds

    // 3. The Test Sequence
    initial begin
        $dumpfile("wave_top.vcd");
        $dumpvars(0, spi_top_tb);

        // --- INITIALIZE ---
        rst_n = 0;
        wr_en = 0;
        wr_data = 0;
        slave_sel = 3'b001; // Talk to Slave 1
        cpol = 0;           // SPI Mode 0
        cpha = 0;
        clk_div = 16'd4;    // Slow clock down
        
        #20 rst_n = 1;      // Release reset
        #20;

        // --- BURST WRITE TO FIFO ---
        $display("--- CPU BURST WRITING TO FIFO ---");
        
        // Word 1
        @(posedge clk);
        wr_en = 1;
        wr_data = 32'hAAAA_BBBB; // UPGRADED to 32-bit
        
        // Word 2
        @(posedge clk);
        wr_data = 32'h5555_1111; // UPGRADED to 32-bit
        
        // Word 3
        @(posedge clk);
        wr_data = 32'h1234_5678; // UPGRADED to 32-bit
        
        // CPU is done. Stop writing.
        @(posedge clk);
        wr_en = 0; 
        $display("--- CPU FINISHED. WAITING FOR DMA ---");

        // --- WAIT FOR HARDWARE TO FINISH ---
        // We wait enough time for 3 full 32-bit SPI transfers at divided clock speed.
        #8000; // UPGRADED wait time
        
        $display("--- SIMULATION COMPLETE ---");
        $finish;
    end

endmodule
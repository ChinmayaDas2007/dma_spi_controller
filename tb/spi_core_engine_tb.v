`timescale 1ns / 1ps

module spi_core_engine_tb;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg [15:0] data_in;
    reg        miso;
    reg        cpol;
    reg        cpha;
    reg [15:0] clk_div;

    wire [15:0] data_out;
    wire        mosi;
    wire        sclk;
    wire        busy;
    wire        done;

    spi_core_engine uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .data_in(data_in),
        .miso(miso),
        .cpol(cpol),
        .cpha(cpha),
        .clk_div(clk_div),
        .data_out(data_out),
        .mosi(mosi),
        .sclk(sclk),
        .busy(busy),
        .done(done)
    );

    // 1. Generate Fast System Clock (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 2. Simulate a Sensor responding on the MISO line
    // It just toggles between 0 and 1 on the falling edge of SCLK
    always @(negedge sclk) begin
        miso <= ~miso;
    end

    // 3. Main Test Sequence
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, spi_core_engine_tb);

        // Initialize Everything
        rst_n = 0;
        start = 0;
        data_in = 16'hA5A5; // The data we are sending
        miso = 0;
        cpol = 0;           // SPI Mode 0
        cpha = 0;
        clk_div = 16'd4;    // Slow the clock down

        #20 rst_n = 1;      // Release reset
        #20;

        // Fire the Engine
        $display("--- FIRING SPI ENGINE ---");
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0; // It only needs a 1-tick pulse to start

        // Wait for the hardware to tell us it is finished
        wait(done == 1);
        $display("--- TRANSMISSION COMPLETE ---");
        $display("Master Sent: %h", data_in);
        $display("Master Received (from dummy sensor): %h", data_out);

        #100 $finish;
    end

endmodule
module spi_top (
    input  wire        clk,
    input  wire        rst_n,
    
    // CPU Interface (To TX FIFO)
    input  wire        wr_en,
    input  wire [31:0] wr_data,     // UPGRADED to 32-bit
    output wire        tx_full,
    
    // SPI Physical Pins
    output wire        sclk,
    output wire        mosi,
    input  wire        miso_s1,
    input  wire        miso_s2,
    input  wire        miso_s3,
    output wire [2:0]  ss_n,        // Active-low Slave Selects
    
    // Config
    input  wire [2:0]  slave_sel,   // Which slave to talk to
    input  wire        cpol,
    input  wire        cpha,
    input  wire [15:0] clk_div      // Clock divider stays 16-bit
);

    // --- INTERNAL WIRES (The 'Solder' between chips) ---
    wire [31:0] fifo_to_dma_data;   // UPGRADED to 32-bit
    wire        fifo_empty;
    wire        dma_to_fifo_rd_en;
    
    wire        dma_to_spi_start;
    wire        spi_to_dma_done;
    wire        spi_busy;
    
    wire        combined_miso;

    // 1. Instantiation: TX FIFO (The Warehouse)
    sync_fifo #( .DATA_WIDTH(32), .DEPTH(16) ) tx_buffer ( // UPGRADED to 32-bit
        .clk(clk),
        .rst_n(rst_n),
        .write_en(wr_en),
        .read_en(dma_to_fifo_rd_en),
        .data_in(wr_data),
        .data_out(fifo_to_dma_data),
        .empty(fifo_empty),
        .full(tx_full)
    );

    // 2. Instantiation: DMA Controller (The Brain)
    dma_control_fsm dma_unit (
        .clk(clk),
        .rst_n(rst_n),
        .fifo_empty(fifo_empty),
        .fifo_read_en(dma_to_fifo_rd_en),
        .spi_busy(spi_busy),
        .spi_done(spi_to_dma_done),
        .spi_start(dma_to_spi_start),
        .dma_active() // Unused for now
    );

    // 3. Instantiation: MISO Multiplexer (The Traffic Cop)
    miso_priority_mux mux_unit (
        .slave_select(slave_sel),
        .miso_s1(miso_s1),
        .miso_s2(miso_s2),
        .miso_s3(miso_s3),
        .miso_out(combined_miso)
    );

    // 4. Instantiation: SPI Core (The Mouth)
    spi_core_engine spi_unit (
        .clk(clk),
        .rst_n(rst_n),
        .start(dma_to_spi_start),
        .data_in(fifo_to_dma_data),
        .miso(combined_miso),
        .cpol(cpol),
        .cpha(cpha),
        .clk_div(clk_div),
        .data_out(), // We could add an RX FIFO here later
        .mosi(mosi),
        .sclk(sclk),
        .busy(spi_busy),
        .done(spi_to_dma_done)
    );

    // 5. Slave Select Decoder
    assign ss_n = ~slave_sel; 

endmodule
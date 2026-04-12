module spi_core_engine (
    input  wire        clk,        // System Clock (fast)
    input  wire        rst_n,      // Active-low reset
    input  wire        start,      // Trigger from the DMA to begin sending
    input  wire [31:0] data_in,    // 32-bit data to send (from TX FIFO)
    input  wire        miso,       // Master In, Slave Out (from sensor)
    input  wire        cpol,       // Clock Polarity
    input  wire        cpha,       // Clock Phase
    input  wire [15:0] clk_div,    // Divider to slow down the clock
    
    output reg  [31:0] data_out,   // 32-bit data received (to RX FIFO)
    output reg         mosi,       // Master Out, Slave In
    output reg         sclk,       // Serial Clock to sensor
    output reg         busy,       // Tells DMA we are currently shifting
    output reg         done        // 1-tick pulse telling DMA we finished
);

    // --- INTERNAL REGISTERS ---
    reg [31:0] tx_shift_reg;
    reg [31:0] rx_shift_reg;
    reg [5:0]  bit_count;       // 6-bit counter: Counts from 0 to 32
    reg [15:0] div_count;       // Counts system ticks to generate SPI clock
    
    reg spi_clk_en;             // Internal pulse for SPI clock edges
    reg state;                  // 0 = IDLE, 1 = TRANSFER

    // State Machine Definitions
    localparam IDLE = 1'b0;
    localparam TRANSFER = 1'b1;

    // --- CLOCK DIVIDER LOGIC ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_count <= 0;
            spi_clk_en <= 0;
        end else if (state == TRANSFER) begin
            if (div_count == clk_div) begin
                div_count <= 0;
                spi_clk_en <= 1; 
            end else begin
                div_count <= div_count + 1;
                spi_clk_en <= 0;
            end
        end else begin
            div_count <= 0;
            spi_clk_en <= 0;
        end
    end

    // --- MAIN SPI STATE MACHINE ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sclk <= cpol; 
            mosi <= 0;
            busy <= 0;
            done <= 0;
            bit_count <= 0;
            tx_shift_reg <= 0;
            rx_shift_reg <= 0;
            data_out <= 0;
        end else begin
            done <= 0; 

            case (state)
                IDLE: begin
                    sclk <= cpol; 
                    busy <= 0;
                    if (start) begin
                        state <= TRANSFER;
                        busy <= 1;
                        tx_shift_reg <= data_in; 
                        bit_count <= 0;
                        
                        // If CPHA=0, data must be on MOSI *before* the first clock edge
                        if (cpha == 0) begin
                            mosi <= data_in[31]; // Shift from MSB
                            tx_shift_reg <= {data_in[30:0], 1'b0}; 
                        end
                    end
                end

                TRANSFER: begin
                    if (spi_clk_en) begin
                        sclk <= ~sclk; 

                        // Leading Edge
                        if (sclk == cpol) begin 
                            if (cpha == 0) begin
                                rx_shift_reg <= {rx_shift_reg[30:0], miso};
                            end else begin
                                mosi <= tx_shift_reg[31];
                                tx_shift_reg <= {tx_shift_reg[30:0], 1'b0};
                            end
                        end 
                        // Trailing Edge
                        else begin 
                            if (cpha == 0) begin
                                mosi <= tx_shift_reg[31];
                                tx_shift_reg <= {tx_shift_reg[30:0], 1'b0};
                                bit_count <= bit_count + 1;
                            end else begin
                                rx_shift_reg <= {rx_shift_reg[30:0], miso};
                                bit_count <= bit_count + 1;
                            end
                        end

                        // Check if we sent all 32 bits
                        if (bit_count == 32) begin
                            state <= IDLE;
                            busy <= 0;
                            done <= 1; 
                            data_out <= rx_shift_reg; 
                            sclk <= cpol; 
                        end
                    end
                end
            endcase
        end
    end

endmodule
module dma_control_fsm (
    input  wire        clk,
    input  wire        rst_n,
    
    // Interface to FIFO
    input  wire        fifo_empty,
    output reg         fifo_read_en,
    
    // Interface to SPI Core
    input  wire        spi_busy,
    input  wire        spi_done,
    output reg         spi_start,
    
    // Status
    output reg         dma_active
);

    // State Encoding
    localparam IDLE     = 2'b00;
    localparam FETCH    = 2'b01;
    localparam WAIT_SPI = 2'b10;
    localparam DONE     = 2'b11;

    reg [1:0] current_state, next_state;

    // 1. State Register (Sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            current_state <= IDLE;
        else 
            current_state <= next_state;
    end

    // 2. Next State Logic (Combinational)
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (!fifo_empty) next_state = FETCH;
                else             next_state = IDLE;
            end
            FETCH: begin
                next_state = WAIT_SPI;
            end
            WAIT_SPI: begin
                if (spi_done)    next_state = DONE;
                else             next_state = WAIT_SPI;
            end
            DONE: begin
                if (!fifo_empty) next_state = FETCH;
                else             next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // 3. Output Logic (Sequential for clean signals)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_read_en <= 0;
            spi_start    <= 0;
            dma_active   <= 0;
        end else begin
            case (next_state)
                IDLE: begin
                    fifo_read_en <= 0;
                    spi_start    <= 0;
                    dma_active   <= 0;
                end
                FETCH: begin
                    fifo_read_en <= 1; // Pop data from FIFO
                    spi_start    <= 0;
                    dma_active   <= 1;
                end
                WAIT_SPI: begin
                    fifo_read_en <= 0;
                    spi_start    <= 1; // Trigger the SPI engine
                end
                DONE: begin
                    spi_start    <= 0;
                    dma_active   <= 1;
                end
            endcase
        end
    end

endmodule
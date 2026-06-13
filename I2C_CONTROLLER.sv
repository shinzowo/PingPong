`ifdef IS_QUARTUS
`default_nettype none
`endif

module I2C_CONTROLLER #(
  parameter CLK_DIV = 32,
  parameter CLK_CNT_SZ = $clog2(CLK_DIV) 
) (
  input  logic scl_i,
  output logic scl_o,
  output logic scl_e,
  input  logic sda_i,
  output logic sda_o,
  output logic sda_e,
  output logic busy,
  output logic abort,
  output logic success,
  input  logic activate,
  input  logic read,
  input  logic [6:0] address,
  input  logic [7:0] location,
  input  logic [7:0] data,
  input  logic [2:0] data_repeat,
  input  logic clk,
  input  logic reset,
  output logic start_pulse,
  output logic stop_pulse,
  output logic got_ack
);

initial scl_o = 0;
initial scl_e = 0;
initial sda_o = 0;
initial sda_e = 0;
initial busy = 1;
initial abort = 0;
initial success = 0;
initial start_pulse = 0;
initial stop_pulse = 0;
initial got_ack = 0;

localparam S_POWERON = 3'd0,
           S_RESET   = 3'd1,
           S_IDLE    = 3'd2,
           S_START   = 3'd3,
           S_ADDRESS = 3'd4,
           S_DATA1   = 3'd5,
           S_DATA2   = 3'd6,
           S_STOP    = 3'd7;

localparam CLK_DIV_CNT_START = { {(CLK_CNT_SZ-1){1'b0}}, 1'b1 };
localparam CLK_CNT_MAX = CLK_DIV - 1;
logic [CLK_CNT_SZ:0] clk_div_cnt = CLK_DIV_CNT_START;

logic [2:0] state = S_RESET;
logic [1:0] step = 2'b0;
logic [3:0] byte_step = 4'b0;
logic [2:0] byte_idx = 3'h7;

logic is_write;

logic [3:0] poweron_counter = 0;

logic [7:0] k_address;
logic [7:0] k_location, k_data;
logic [2:0] k_data_repeat;

always @(posedge clk) begin

  if (reset) begin
    state <= S_RESET;
    clk_div_cnt <= CLK_DIV_CNT_START;
    sda_e <= 0;
    scl_e <= 0;
    scl_o <= 0;
    sda_o <= 0;
    busy <= 0;
    abort <= 0;
    success <= 0;
  end else if (clk_div_cnt != 0) begin
  
    if (clk_div_cnt == CLK_CNT_MAX)
      clk_div_cnt <= 0;
    else
      clk_div_cnt <= clk_div_cnt + {{(CLK_CNT_SZ - 1){1'b0}}, 1'b1};
    
  end else begin
  
    clk_div_cnt <= {{(CLK_CNT_SZ - 1){1'b0}}, 1'b1};
  
    case (state)

      S_RESET: begin
          poweron_counter <= 0;
          busy <= 1;
          abort <= 0;
          success <= 0;
          sda_e <= 0;
          scl_e <= 0;
          state <= S_POWERON;
      end
    
      S_POWERON:
        if (&poweron_counter) begin
          state <= S_IDLE;
          busy <= 0;
          poweron_counter <= 0;
        end else begin
          busy <= 1;
          poweron_counter <= poweron_counter + 4'd1;
        end
      
      S_IDLE:
        if (activate) begin
          k_address[7:1] <= address;
          k_address[0] <= read;
          k_location <= location;
          k_data <= data;
          k_data_repeat <= data_repeat;
          state <= S_START;
          step <= 0;
          start_pulse <= 1;
          stop_pulse <= 0;
          busy <= 1;
          sda_e <= 1; sda_o <= 0;
          scl_e <= 1; scl_o <= 0;
        end else begin
          busy <= 0;
          scl_e <= 0;
          sda_e <= 0;
          start_pulse <= 0;
          stop_pulse <= 0;
        end
        
      S_START:
        case (step)
          0: begin
              scl_e <= 1; scl_o <= 0; step <= 2'd1;
              sda_e <= 1; sda_o <= 1; 
              start_pulse <= 0;
            end
          1: begin
              scl_o <= 1; step <= 2'd2;
            end
          2: begin
              sda_o <= 0; step <= 2'd3;
            end
          3: begin
              scl_o <= 0; step <= 2'd0;
              state <= S_ADDRESS; byte_step <= 4'd0;
              byte_idx <= 3'd7;
            end
        endcase

      S_ADDRESS, S_DATA1, S_DATA2:
        begin
        
          is_write = 1;

          if (byte_step == 4'd8) begin
          
            if (is_write) case (step)
              0: begin
                  scl_e <= 1; scl_o <= 0;
                  sda_e <= 0;
                  got_ack <= 0;
                end
              1: begin
                  scl_o <= 1;
                end
              2: begin
                  got_ack <= ~sda_i; 
                end
              3: begin
                  got_ack <= got_ack || ~sda_i;
                  scl_o <= 0;
                  if (!sda_i) sda_o <= 0;
                  else if (got_ack) sda_o <= 0;
                  else sda_o <= 1;
                  sda_o <= ~sda_i;
                end
            endcase
            
          end else begin
          
            got_ack <= 0;
          
            if (is_write) case (step)
              0: begin
                  scl_e <= 1; scl_o <= 0;
                  sda_e <= 1; 
                  sda_o <= state == S_ADDRESS ? k_address [byte_idx] :
                          state == S_DATA1   ? k_location[byte_idx] 
                                            : k_data    [byte_idx];
                end
              1: begin
                  scl_o <= 1;
                end
              2: begin
                end
              3: begin
                  scl_o <= 0;
                end
            endcase
          end
        
          if (byte_step == 4'd8 && step == 2'd3) begin
            if (state == S_DATA2) begin
              if (k_data_repeat == 0) begin
                state <= S_STOP;
              end else begin
                k_data_repeat <= k_data_repeat - 3'd1;
              end
            end else begin
              state <= state == S_ADDRESS ? S_DATA1 : S_DATA2;
            end
            byte_step <= 4'd0;
            byte_idx <= 3'd7;
          end else if (step == 2'd3) begin
            byte_step <= byte_step + 3'd1;
            byte_idx <= byte_idx - 2'd1;
          end
        
          step <= step + 2'd1;
        end
      
      S_STOP:
        case (step)
          0: begin
              scl_e <= 1; scl_o <= 0; step <= 2'd1;
              sda_e <= 1; sda_o <= 0; 
            end
          1: begin
              scl_o <= 1; step <= 2'd2;
            end
          2: begin
              sda_o <= 1; step <= 2'd3;
            end
          3: begin
              scl_o <= 0; step <= 2'd0;
              state <= S_IDLE;
              stop_pulse <= 1;
            end
        endcase
        
      default:
        state <= S_RESET;
        
    endcase
  
  end

end

endmodule

`ifdef IS_QUARTUS
`default_nettype wire
`endif

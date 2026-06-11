module setup_rom (
  input  logic [7:0]  address,
  output logic [23:0] data,
  output logic [7:0]  rom_length
);
assign rom_length = 8'd21;

always_comb
  case (address)
    //Power down during setup
    8'd0:  data = 24'h72_41_10;

    // Fixed registers from ADV7513 Programming Guide 
    8'd1:  data = 24'h72_98_03;
    8'd2:  data = 24'h72_9A_E0;
    8'd3:  data = 24'h72_9C_30;
    8'd4:  data = 24'h72_9D_61;
    8'd5:  data = 24'h72_A2_A4;
    8'd6:  data = 24'h72_A3_A4;
    8'd7:  data = 24'h72_E0_D0;
    8'd8:  data = 24'h72_E4_60;
    8'd9:  data = 24'h72_F9_00;

    // 24-bit RGB 4:4:4 with separate syncs and external DE
    8'd10: data = 24'h72_15_00;
    8'd11: data = 24'h72_16_30;
    8'd12: data = 24'h72_17_00;
    8'd13: data = 24'h72_18_46;

    // Input clock capture tuning
    8'd14: data = 24'h72_BA_60;

    // Optional AVI info for RGB / 4:3
    8'd15: data = 24'h72_55_00;
    8'd16: data = 24'h72_56_08;

    // Bring transmitter up after configuration
    8'd17: data = 24'h72_41_00;

    //HDMI mode, no HDCP encryption
    8'd18: data = 24'h72_AF_06;

    //Hot-Plug / Monitor Sense interrupt handling 
    8'd19: data = 24'h72_96_C0; // Clear pending HPD + monitor-sense IRQs
    8'd20: data = 24'h72_94_C0; // Enable HPD + monitor-sense IRQs
    
    default: data = 24'h00_00_00;
  endcase

endmodule

// Основной модуль ADV7513_SETUP
module adv7513_setup #(
  parameter CNT_200MS = 32'd10_000_000  // 200ms at 50MHz
) (
  input logic clk,
  input logic rst,
  
  // Interface with the I2C controller
  output logic       i2c_activate,
  input  logic       i2c_busy,
  output logic [6:0] i2c_address,
  output logic       i2c_readnotwrite,
  output logic [7:0] i2c_byte1,
  output logic [7:0] i2c_byte2,
  
  // Setup outputs
  output logic active,
  output logic done,
  
  // Debugging outputs
  output logic is_busywait,
  output logic is_busyseen
);

initial active = 0;
initial done = 0;

localparam S_RESET    = 3'd0,
           S_WAIT     = 3'd1,
           S_SEND     = 3'd2,
           S_BUSYWAIT = 3'd3,
           S_DONE     = 3'd4;

logic [2:0]  setup_state = S_RESET;
logic [7:0]  rom_step;
logic [7:0]  rom_length;
logic [23:0] cnt_wait;
logic [23:0] rom_comb;
logic busy_seen;

setup_rom setup_rom_inst(
  .address(rom_step),
  .data(rom_comb),
  .rom_length(rom_length)
);

assign is_busyseen = busy_seen;
assign is_busywait = (setup_state == S_BUSYWAIT);

always_ff @(posedge clk) begin
  if (rst) begin
    setup_state <= S_RESET;
    active <= 0;
    done <= 0;
  end else case (setup_state)
  
    S_RESET: begin
      rom_step <= 0;
      cnt_wait <= 0;
      setup_state <= S_WAIT;
      i2c_activate <= 0;
      busy_seen <= 0;
      active <= 1;
      done <= 0;
    end
    
    S_WAIT: begin
      if (cnt_wait == CNT_200MS) begin
        setup_state <= S_BUSYWAIT;
        busy_seen <= 1;
        rom_step <= 0;
        cnt_wait <= 0;
      end else begin
        cnt_wait <= cnt_wait + 24'd1;
        i2c_activate <= 0;
        busy_seen <= 0;
      end
    end
    
    S_SEND: begin
      if (rom_step == rom_length)
        setup_state <= S_DONE;
      else begin
        busy_seen <= 0;
        setup_state <= S_BUSYWAIT;
        i2c_activate <= 1;
        {i2c_address, i2c_readnotwrite, i2c_byte1, i2c_byte2} <= rom_comb;
      end
    end
    
    S_BUSYWAIT: begin
      if (!busy_seen) begin
        if (i2c_busy) begin
          busy_seen <= 1;
          i2c_activate <= 0;
          rom_step <= rom_step + 8'd1;
        end
      end else if (!i2c_busy) begin
        busy_seen <= 0;
        i2c_activate <= 0;
        setup_state <= S_SEND;
      end
    end
    
    S_DONE: begin
      active <= 0;
      done <= 1;
      i2c_activate <= 0;
    end
    
    default: begin
      setup_state <= S_RESET;
    end
  
  endcase
end

endmodule

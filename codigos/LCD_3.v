// =============================================================================
// LABORATORIO 04 - PARTE 1: Texto estático en LCD 16x2
// Tarjeta: Altera Cyclone IV (50 MHz)
// =============================================================================
//
// FILA 1: "5 en este     " (13 chars + 3 espacios = 16 celdas) estados 8–23
// CAMBIO A FILA 2: 0xC0                                          estado  24
// FILA 2: "laboratorio     " (11 chars + 5 espacios = 16 celdas) estados 25–40
//
// =============================================================================

module LCD(
    input  clk,
    output rs,
    output en,
    output rw,
    output [7:0] dat
);

    localparam DELAY_40MS  = 21'd2_000_000;
    localparam DELAY_5MS   = 21'd250_000;
    localparam DELAY_100US = 21'd5_000;
    localparam DELAY_2MS   = 21'd100_000;
    localparam EN_HIGH_T   = 11'd1_250;

    reg        rs_r;
    reg        en_r;
    reg [7:0]  dat_r;
    reg [5:0]  state;
    reg        busy;
    reg [20:0] delay_cnt;
    reg [10:0] en_cnt;
    reg [20:0] wait_time;
    reg [8:0]  lcd_cmd;

    assign en  = en_r;
    assign rs  = rs_r;
    assign dat = dat_r;
    assign rw  = 1'b0;

    always @(posedge clk) begin

        if (!busy) begin
            busy      <= 1'b1;
            delay_cnt <= 21'd0;
            en_cnt    <= 11'd0;
            en_r      <= 1'b0;

            case (state)
                // ===========================================================
                // INICIALIZACIÓN (sin cambios)
                // ===========================================================
                6'd0:  begin lcd_cmd <= {1'b0, 8'h30}; wait_time <= DELAY_40MS;  state <= 6'd1;  end
                6'd1:  begin lcd_cmd <= {1'b0, 8'h30}; wait_time <= DELAY_5MS;   state <= 6'd2;  end
                6'd2:  begin lcd_cmd <= {1'b0, 8'h30}; wait_time <= DELAY_100US; state <= 6'd3;  end
                6'd3:  begin lcd_cmd <= {1'b0, 8'h38}; wait_time <= DELAY_2MS;   state <= 6'd4;  end
                6'd4:  begin lcd_cmd <= {1'b0, 8'h08}; wait_time <= DELAY_2MS;   state <= 6'd5;  end
                6'd5:  begin lcd_cmd <= {1'b0, 8'h01}; wait_time <= DELAY_5MS;   state <= 6'd6;  end
                6'd6:  begin lcd_cmd <= {1'b0, 8'h06}; wait_time <= DELAY_2MS;   state <= 6'd7;  end
                6'd7:  begin lcd_cmd <= {1'b0, 8'h0C}; wait_time <= DELAY_2MS;   state <= 6'd8;  end

                // ===========================================================
                // FILA 1: "5 en este     " (16 celdas, estados 8–23)
                // ===========================================================
                6'd8:  begin lcd_cmd <= {1'b1, 8'h35}; wait_time <= DELAY_2MS; state <= 6'd9;  end // '5'
                6'd9:  begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd10; end // ' '
                6'd10: begin lcd_cmd <= {1'b1, 8'h65}; wait_time <= DELAY_2MS; state <= 6'd11; end // 'e'
                6'd11: begin lcd_cmd <= {1'b1, 8'h6E}; wait_time <= DELAY_2MS; state <= 6'd12; end // 'n'
                6'd12: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd13; end // ' '
                6'd13: begin lcd_cmd <= {1'b1, 8'h65}; wait_time <= DELAY_2MS; state <= 6'd14; end // 'e'
                6'd14: begin lcd_cmd <= {1'b1, 8'h73}; wait_time <= DELAY_2MS; state <= 6'd15; end // 's'
                6'd15: begin lcd_cmd <= {1'b1, 8'h74}; wait_time <= DELAY_2MS; state <= 6'd16; end // 't'
                6'd16: begin lcd_cmd <= {1'b1, 8'h65}; wait_time <= DELAY_2MS; state <= 6'd17; end // 'e'
                6'd17: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd18; end // ' '
                6'd18: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd19; end // ' '
                6'd19: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd20; end // ' '
                6'd20: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd21; end // ' '
                6'd21: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd22; end // ' '
                6'd22: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd23; end // ' '
                6'd23: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd24; end // ' '

                // ===========================================================
                // CAMBIO A FILA 2: dirección DDRAM 0x40 → comando 0xC0
                // ===========================================================
                6'd24: begin lcd_cmd <= {1'b0, 8'hC0}; wait_time <= DELAY_2MS; state <= 6'd25; end

                // ===========================================================
                // FILA 2: "laboratorio     " (16 celdas, estados 25–40)
                // ===========================================================
                6'd25: begin lcd_cmd <= {1'b1, 8'h6C}; wait_time <= DELAY_2MS; state <= 6'd26; end // 'l'
                6'd26: begin lcd_cmd <= {1'b1, 8'h61}; wait_time <= DELAY_2MS; state <= 6'd27; end // 'a'
                6'd27: begin lcd_cmd <= {1'b1, 8'h62}; wait_time <= DELAY_2MS; state <= 6'd28; end // 'b'
                6'd28: begin lcd_cmd <= {1'b1, 8'h6F}; wait_time <= DELAY_2MS; state <= 6'd29; end // 'o'
                6'd29: begin lcd_cmd <= {1'b1, 8'h72}; wait_time <= DELAY_2MS; state <= 6'd30; end // 'r'
                6'd30: begin lcd_cmd <= {1'b1, 8'h61}; wait_time <= DELAY_2MS; state <= 6'd31; end // 'a'
                6'd31: begin lcd_cmd <= {1'b1, 8'h74}; wait_time <= DELAY_2MS; state <= 6'd32; end // 't'
                6'd32: begin lcd_cmd <= {1'b1, 8'h6F}; wait_time <= DELAY_2MS; state <= 6'd33; end // 'o'
                6'd33: begin lcd_cmd <= {1'b1, 8'h72}; wait_time <= DELAY_2MS; state <= 6'd34; end // 'r'
                6'd34: begin lcd_cmd <= {1'b1, 8'h69}; wait_time <= DELAY_2MS; state <= 6'd35; end // 'i'
                6'd35: begin lcd_cmd <= {1'b1, 8'h6F}; wait_time <= DELAY_2MS; state <= 6'd36; end // 'o'
                6'd36: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd37; end // ' '
                6'd37: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd38; end // ' '
                6'd38: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd39; end // ' '
                6'd39: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd40; end // ' '
                6'd40: begin lcd_cmd <= {1'b1, 8'h20}; wait_time <= DELAY_2MS; state <= 6'd41; end // ' '

                // ===========================================================
                // ESTADO FINAL: texto estático, se queda aquí
                // ===========================================================
                default: begin busy <= 1'b0; end
            endcase

        end else begin
            if (delay_cnt < wait_time) begin
                delay_cnt <= delay_cnt + 21'd1;
                en_r      <= 1'b0;
                rs_r      <= lcd_cmd[8];
                dat_r     <= lcd_cmd[7:0];
            end
            else if (en_cnt < EN_HIGH_T) begin
                en_r   <= 1'b1;
                en_cnt <= en_cnt + 11'd1;
            end
            else begin
                en_r <= 1'b0;
                busy <= 1'b0;
            end
        end
    end

endmodule
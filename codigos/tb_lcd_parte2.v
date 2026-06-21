`timescale 1ns/1ps
//==============================================================================
// TESTBENCH - lcd_parte2
// Verifica:
//   1) Logica de clasificacion BAJO / MEDI / ALTO para entrada_a y entrada_b
//   2) Protocolo de escritura hacia la LCD (rs, en, rw, dat) en el tiempo
//
// El reloj del DUT es de 50 MHz (periodo 20 ns), igual que en la tarjeta.
// La FSM del modulo vuelve al estado 8 cada vez que termina de refrescar
// las dos filas de la LCD (estado 39 -> estado 8), asi que ese evento se
// usa aqui para saber cuando ya se mostro por completo un valor antes de
// cambiar al siguiente.
//==============================================================================
module tb_lcd_parte2;

    // ---------------------------------------------------------------
    // Senales de conexion con el DUT
    // ---------------------------------------------------------------
    reg        clk;
    reg  [3:0] entrada_a;
    reg  [3:0] entrada_b;
    wire       rs, en, rw;
    wire [7:0] dat;

    // ---------------------------------------------------------------
    // DUT
    // ---------------------------------------------------------------
    lcd_parte2 uut (
        .clk       (clk),
        .entrada_a (entrada_a),
        .entrada_b (entrada_b),
        .rs        (rs),
        .en        (en),
        .rw        (rw),
        .dat       (dat)
    );

    // ---------------------------------------------------------------
    // Reloj 50 MHz -> periodo 20 ns
    // ---------------------------------------------------------------
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // ---------------------------------------------------------------
    // Contador de refrescos completos de pantalla
    // ---------------------------------------------------------------
    reg [31:0] refresh_count;
    reg        was_state8;

    initial begin
        refresh_count = 0;
        was_state8    = 0;
    end

    always @(posedge clk) begin
        if (uut.state == 6'd8 && !was_state8) begin
            refresh_count <= refresh_count + 1;
            was_state8    <= 1'b1;
        end else if (uut.state != 6'd8) begin
            was_state8 <= 1'b0;
        end
    end

    // ---------------------------------------------------------------
    // Verificacion de la clasificacion BAJO / MEDI / ALTO
    // (logica combinacional: no depende del reloj de la LCD)
    // ---------------------------------------------------------------
    task check_clasificacion;
        input [7:0]  canal;     // solo para el mensaje ("A" o "B")
        input [3:0]  valor;
        input [7:0]  r0, r1, r2, r3;
        reg   [31:0] esperado;
        begin
            if (valor <= 4)
                esperado = "BAJO";
            else if (valor <= 10)
                esperado = "MEDI";
            else
                esperado = "ALTO";

            if ({r0,r1,r2,r3} !== esperado)
                $display("  [FALLO] Canal %s  valor=%0d  obtenido=%s  esperado=%s",
                          canal, valor, {r0,r1,r2,r3}, esperado);
            else
                $display("  [OK]    Canal %s  valor=%0d  etiqueta=%s",
                          canal, valor, {r0,r1,r2,r3});
        end
    endtask

    // ---------------------------------------------------------------
    // Estimulos principales
    // ---------------------------------------------------------------
    integer i;
    integer objetivo;

    initial begin
        entrada_a = 4'd0;
        entrada_b = 4'd0;

        // Espera a que termine la inicializacion de la LCD y se
        // complete el primer refresco con los valores iniciales (0,0)
        wait (refresh_count == 1);

        $display("==================================================");
        $display(" VERIFICACION DE CLASIFICACION BAJO / MEDI / ALTO");
        $display("==================================================");

        // Barrido 0-15 (mismos 16 estados de las evidencias fotograficas).
        // Si la simulacion tarda demasiado por los delays reales de la LCD,
        // se puede reducir esta lista a los valores criticos de borde:
        // 0, 4, 5, 10, 11, 15 (limites entre BAJO/MEDI/ALTO).
        for (i = 0; i <= 15; i = i + 1) begin
            entrada_a = i[3:0];
            entrada_b = i[3:0];

            #1; // deja asentar la logica combinacional
            $display("--- Estado %0d (entrada_a=entrada_b=%0d) ---", i, i);
            check_clasificacion("A", entrada_a, uut.a_r0, uut.a_r1, uut.a_r2, uut.a_r3);
            check_clasificacion("B", entrada_b, uut.b_r0, uut.b_r1, uut.b_r2, uut.b_r3);

            // Espera a que la LCD termine de refrescar la pantalla
            // completa con este valor antes de pasar al siguiente
            objetivo = refresh_count + 1;
            wait (refresh_count == objetivo);
        end

        $display("==================================================");
        $display(" SIMULACION FINALIZADA");
        $display("==================================================");
        $stop;
    end

    // ---------------------------------------------------------------
    // Volcado de senales para ver las formas de onda (rs, en, rw, dat)
    // en GTKWave / ModelSim / Quartus para las capturas del informe
    // ---------------------------------------------------------------
    initial begin
        $dumpfile("tb_lcd_parte2.vcd");
        $dumpvars(0, tb_lcd_parte2);
    end

endmodule

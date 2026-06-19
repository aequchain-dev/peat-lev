import numpy as np
from peat_sim_v2 import ArrayParams, SixOscillatorArray, OscillatorParams, CoilParams, AnalyticalModel, simulate_single_config, create_oscillator_for_scale

def run_verification():
    test_cases = [
        (5.0, 30.0, 0.15, 0.30),     # Drone
        (115.0, 15.0, 0.15, 0.20),    # Human
        (1200.0, 10.0, 0.12, 0.25),   # Hovercar
    ]
    
    print("═" * 60)
    print("Verification: Cross-check Analytical vs Numerical")
    print("═" * 60)
    
    for M, f, ratio, eta in test_cases:
        print(f"\nCase: {M} kg, {f} Hz, η={eta}")
        osc = create_oscillator_for_scale(M, f, ratio, eta)
        osc.axis = 'Z'
        
        balance = AnalyticalModel.full_energy_balance(osc, M)
        
        # Run simulation with fixed-step RK4 integrator
        sim_time = 0.5  
        res = simulate_single_config(osc, sim_time=sim_time)
        
        # Calculate average power over the last 5 cycles to avoid transients
        num_cycles = int(sim_time * f)
        t_start_steady = sim_time - (5.0 / f)
        
        # Find index for t_start_steady
        t_array = np.array(res['time'])
        idx_start = np.searchsorted(t_array, t_start_steady)
        
        def get_avg_power(energy_list):
            # Power = (E_final - E_start) / (t_final - t_start)
            return (energy_list[-1] - energy_list[idx_start]) / (sim_time - t_array[idx_start])

        p_pump_num = get_avg_power(res['E_pump_J'])
        p_pickup_num = get_avg_power(res['E_pickup_J'])
        p_copper_num = get_avg_power(res['E_loss_J'])
        p_net_num = p_pump_num - p_copper_num - p_pickup_num
        
        metrics = {
            'P_pump': (balance['P_pump_W'], p_pump_num),
            'P_pickup': (balance['P_pickup_W'], p_pickup_num),
            'P_copper': (balance['P_copper_W'], p_copper_num),
            'P_net': (balance['P_net_W'], p_net_num)
        }
        
        print(f"  {'Metric':<12} | {'Analytical':<12} | {'Numerical':<12} | {'Error %':<10}")
        print(f"  {'-'*45}")
        for name, (ana, num) in metrics.items():
            err = abs(ana - num) / (abs(ana) + 1e-6) * 100
            print(f"  {name:<12} | {ana:>12.2f} | {num:>12.2f} | {err:>9.2f}%")
        
        # Thrust check: Average net force over last 5 cycles
        f_net_array = np.array(res['F_net'])
        f_num = np.mean(f_net_array[idx_start:])
        f_ana = balance['F_thrust_N']
        print(f"  F_thrust    | {f_ana:>12.2f} | {f_num:>12.2f} | {abs(f_ana-f_num)/f_ana*100:>9.2f}%")

    print("\nCalibration controller disturbance test:")
    from calibration_controller import run_demo
    run_demo()

if __name__ == '__main__':
    run_verification()

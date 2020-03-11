;;
;;
;;

(ammo-select-table
   (aircraft ;; matches any air vehicle
      (target-type 1 2 -1 -1 -1 -1 -1)
      (ammo
         (SA-21-missile  ;; these names need to match resource names
            (munition-type  2 1 222 1 44 3 0)
            (warhead  0)
         )
      )
   )
   (exocet-cruise-missile
      (target-type 2 6 71 1 1 -1 -1)
      (ammo
         (SA-21-missile  ;; these names need to match resource names
            (munition-type  2 1 222 1 44 3 0)
            (warhead  0)
         )
      )
    )
    (tomahawk-cruise-missile
      (target-type 2 9 225 1 19 -1 -1)
      (ammo
         (SA-21-missile  ;; these names need to match resource names
            (munition-type  2 1 222 1 44 3 0)
            (warhead  0)
         )
      )
    )
	(M-39-missile
      (target-type 2 9 225 1 17 1 1)
      (ammo
         (SA-21-missile  ;; these names need to match resource names
            (munition-type  2 1 222 1 44 3 0)
            (warhead  0)
         )
      )
	)
	(strategic-munitions
      (target-type 2 10 -1 -1 -1 -1 -1)
      (ammo
         (SA-21-missile  ;; these names need to match resource names
            (munition-type  2 1 222 1 44 3 0)
            (warhead  0)
         )
      )
    )
	(tactical-munitions
      (target-type 2 11 -1 -1 -1 -1 -1)
      (ammo
         (SA-21-missile  ;; these names need to match resource names
            (munition-type  2 1 222 1 44 3 0)
            (warhead  0)
         )
      )
   )
)

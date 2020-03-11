;;
;; File - M61.asl
;;
;;
;; Copyright (c) 2014 MAK Technologies, Inc.
;; All rights reserved.
;;
;; Ammo Select Table for the M61 gatling gun (for US attack aircraft.)
;; (for example only!)
;;
;; This gun cannot be loaded with different ammunition during a
;; mission; however this table is needed so that the gun controller
;; knows that it has a munition to fire on a given entity type.

(ammo-select-table
   (lifeform ;; matches any lifeform
      (target-type  3 -1 -1 -1 -1 -1 -1)
      (ammo
         (PGU-28B-20mm ;; these names need to match resource names
            (munition-type  2 2 225 2 2 8 0)
            (warhead  0)
         )
      )
   )
   (shooting-target ;; matches any shooting target
      (target-type  5 1 0 5 21 0 -1)
      (ammo
         (PGU-28B-20mm ;; these names need to match resource names
            (munition-type  2 2 225 2 2 8 0)
            (warhead  0)
         )
      )
   )
   (land-platform 
      (target-type  1 1 -1  -1 -1 -1 -1)
      (ammo
         (PGU-28B-20mm
            (munition-type  2 2 225 2 2 8 0)
            (warhead  0)
         )
      )
   )
   (air-platform 
      (target-type  1 2 -1  -1 -1 -1 -1)
      (ammo
         (PGU-28B-20mm
            (munition-type  2 2 225 2 2 8 0)
            (warhead  0)
         )
      )
   )
)
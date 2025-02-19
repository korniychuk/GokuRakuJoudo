(ns karabiner-configurator.data
  (:require
   [karabiner-configurator.keys-info :refer :all]
   [karabiner-configurator.misc :refer :all]))

(declare rule-id)

(defn init-rule-id []
  (def rule-id -1))

(defn next-rule-id
  "return the next rule id

   store each rule in a vector and use the index as their id
   the data structure will also store conditions used in the rule
   so that we know what condition used in each profile"
  []
  (def rule-id (inc rule-id))
  rule-id)

(declare conf-data)

(defn init-conf-data
  []
  (init-rule-id)
  (def user-default-profile-name :Default)
  (def conf-data {:profiles {:Default {:sim 50 ;; basic.simultaneous_threshold_milliseconds
                                       :delay 500 ;; basic.to_delayed_action_delay_milliseconds
                                       :alone 1000 ;; basic.to_if_alone_timeout_milliseconds
                                       :held 500 ;; basic.to_if_held_down_threshold_milliseconds
                                       :default true}}
                  :applications {}
                  :devices {}
                  :input-sources {}
                  :modifiers {}
                  :froms {}
                  :tos {}
                  :layers {}
                  :simlayers {}
                  :simlayer-threshold 250}))

(defn applications? [k] (nn? (k (:applications conf-data))))
(defn devices? [k] (nn? (k (:devices conf-data))))
(defn input-sources? [k] (nn? (k (:input-sources conf-data))))
(defn modifiers? [k] (nn? (k (:modifiers conf-data))))
(defn froms? [k] (nn? (k (:froms conf-data))))
(defn layers? [k] (nn? (k (:layers conf-data))))
(defn simlayers? [k] (nn? (k (:simlayers conf-data))))
(defn templates? [k-or-vec]
  (cond (keyword? k-or-vec)
        (contains? (:templates conf-data) k-or-vec)
        (vector? k-or-vec)
        (contains? (:templates conf-data) (first k-or-vec))))
(defn noti? [vec]
  (and (vector? vec)
       (let [[k id text] vec]
         (and (= k :noti)
              (or (keyword? id)
                  (string? id))
              (or (string? text)
                  (keyword? text)
                  (nil? text))))))
(defn raw-rule? [rule]
  (and (map? rule)
       (or (= :basic (:type rule))
           (= :mouse_motion_to_scroll (:type rule)))))

(defn profile? [k]
  (and (keyword? k) (k (:profiles conf-data))))

(def default-profile {:Default {:sim 50 ;; basic.simultaneous_threshold_milliseconds
                                :delay 500 ;; basic.to_delayed_action_delay_milliseconds
                                :alone 1000 ;; basic.to_if_alone_timeout_milliseconds
                                :held 500 ;; basic.to_if_held_down_threshold_milliseconds
                                :default true}})

(def user-default-profile-name :Default)

(defn update-user-default-profile-name [profile-name]
  (massert
   (keyword? profile-name)
   (str "invalid profile name " profile-name ", profile name must be a keyword"))
  (def user-default-profile-name profile-name))

(defn special-modi-k?
  [k]
  (and (keyword? k) (or (= \! (first (name k))) (= \# (first (name k))))))

(defn pkey?
  [pkeymap]
  (and (map? pkeymap)
       (->> pkeymap
            keys
            first
            (= :pkey))
       (->> pkeymap
            first
            second
            (get keys-info)
            (:button)
            true?)))

(defn k?
  [k]
  (if (keyword? k)
    (nn? (k keys-info))))

(defn modifier-k?
  [k]
  (k? k)
  (true? (:modifier (k keys-info))))

(defn from-k?
  [k]
  (k? k)
  (nil? (:not-from (k keys-info))))

(defn to-k?
  [k]
  (k? k)
  (nil? (:not-to (k keys-info))))

(defn consumer-k?
  [k]
  (k? k)
  (true? (:consumer-key (k keys-info))))

(defn pointing-k?
  [k]
  (k? k)
  (true? (:button (k keys-info))))

(def mkey-keyword {:x {:name :x}
                   :y {:name :y}
                   :vwheel {:name :vertical_wheel}
                   :hwheel {:name :horizontal_wheel}
                   :speed {:name :speed_multiplier}})

(defn mouse-keyword?
  [k]
  (nn? (k mkey-keyword)))

(defn mouse-key-name
  [k]
  (massert (mouse-keyword? k) (str "invalid mouse key keyword " k))
  (:name (k mkey-keyword)))

(defn special-modi-k?
  [k]
  (if (keyword? k)
    (contains?? [\! \#] (first (name k)))))

(defn find-condition-keyword
  [kw]
  (cond (contains? (:applications conf-data))
        {:name :application
         :value (kw (:applications conf-data))}
        (contains? (:devices conf-data))
        {:name :devices
         :value (kw (:devices conf-data))}
        (contains? (:input-sources conf-data))
        {:name :input-sources
         :value (kw (:input-sources conf-data))}
        (contains? (:simlayers conf-data))
        {:name :simlayers
         :value (kw (:simlayers conf-data))}))

(defn update-conf-data
  [data]
  (def conf-data data))

(defn assoc-conf-data
  [key data]
  (def conf-data (assoc conf-data key data)))

(defn assoc-in-conf-data
  [keys-vector data]
  (def conf-data (assoc-in conf-data keys-vector data)))

(def output "output data that will convert into json string" [])

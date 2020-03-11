class ui {
    ui_GroundVehicleParam() {
        var div = document.createElement("div");

        var innerHTML = "<div class=\"content\">" +
            "          <form class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label>简称:</label>" +
            "              <input type=\"input\" class=\"form-control short-name\" placeholder=\"简称\">" +
            "            </div>" +
            "          </form>" +
            "          <div class=\"panel panel-primary size myForm\">" +
            "            <div class=\"panel-heading \">大小</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group dimensions\">" +
            "                  <label >尺寸(长,宽,高)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control length\" placeholder=\"长\">" +
            "                  <input type=\"input\" class=\"form-control width\"  placeholder=\"宽\">" +
            "                  <input type=\"input\" class=\"form-control height\" placeholder=\"高\">" +
            "                </div>" +
            "                <div class=\"form-group offset\">" +
            "                  <label >偏移(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control offset-front\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control offset-right\" placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control offset-up\"    placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"SelectComboBox form-inline\">" +
            "                  <label>原点</label>" +
            "                  <select class=\"combobox form-control offsetType\">" +
            "                    <option value=\"center\">中心</option>" +
            "                    <option value=\"ground-center\">底部中点</option>" +
            "                    <option value=\"custom\">自定义</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group left-support\">" +
            "                  <label >左支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control left-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control left-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control left-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group right-support\">" +
            "                  <label >右支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control right-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control right-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control right-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group other-support\">" +
            "                  <label >其他支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control other-support-forward\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control other-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control other-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"btn-group\" role=\"group\" aria-label=\"...\">" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <div class=\"checkbox\" style=\"line-height:34px; margin-left: 15px;\">" +
            "                    <label>" +
            "                      <input type=\"checkbox\" class=\"dealWithEliminate\"> 从批处理中更新排除" +
            "                    </label>" +
            "                  </div>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">动作</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >动力学：</label>" +
            "                  <select class=\"form-control movement-system\">" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >质量(kg)：</label>" +
            "                  <input type=\"input\" class=\"form-control mass\" placeholder=\"质量\">" +
            "                </div> " +
            "                <div class=\"form-group\">" +
            "                  <label >最大速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control max-speed\"  placeholder=\"最大速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >默认速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control ordered-speed\" placeholder=\"默认速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大倒速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control max-reverse-speed\" placeholder=\"最大倒速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >转弯半径(m):</label>" +
            "                  <input type=\"input\" class=\"form-control turning-radius\" placeholder=\"转弯半径\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大斜率(%):</label>" +
            "                  <input type=\"input\" class=\"form-control max-slope\"  placeholder=\"最大斜率\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-acceleration\" placeholder=\"最大加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大减速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-deceleration\" placeholder=\"最大减速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大侧加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-lateral-acceleration\" placeholder=\"最大侧加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大角速度(deg/s):</label>" +
            "                  <input type=\"input\" class=\"form-control max-pivot-speed\" placeholder=\"最大角速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-pivot\"> 可转动" +
            "                  </label>" +
            "                </div>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-embark\"> 可乘坐" +
            "                  </label>" +
            "                </div>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-move-onto-embarked\"> 可移植到敌对势力上" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-be-embarked-upon\"> 可以开始" +
            "                  </label>" +
            "                </div>" +
            "                <button class=\"btn btn-default\" type=\"button\" style=\"margin-left: 20px;\">配置...</button>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"protect-from-collateral-damage\"> 保护登船实体免受附带损害" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"use-object-geometry\" > 在仿真引擎中使用详细的几何图形" +
            "                  </label>" +
            "                </div>" +
            "                <button class=\"btn btn-default\" type=\"button\">选择</button>" +
            "                <div class=\"form-group\">" +
            "                  <label >航行数据</label>" +
            "                  <input type=\"input\" class=\"form-control SaleData\"  placeholder=\"航行数据\" style=\"width:35%;\">" +
            "                  <button class=\"btn btn-default\" type=\"button\">生成</button>" +
            "                  <button class=\"btn btn-default\" type=\"button\">清除</button>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">传感信号</div>" +
            "            <div class=\"panel-body sensorSignatures\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >预定义信号：</label>" +
            "                  <select class=\"form-control PredefinedSignal\">" +
            "                    <option value=\"Standard Building\">Standard Building</option>" +
            "                    <option value=\"Standard Fixed Wing\">Standard Fixed Wing</option>" +
            "                    <option value=\"Standard Ground Vehicle\">Standard Ground Vehicle</option>" +
            "                    <option value=\"Standard Human\">Standard Human</option>" +
            "                    <option value=\"Standard Rotary Wing\">Standard Rotary Wing</option>" +
            "                    <option value=\"Standard Ship\">Standard Ship</option>" +
            "                    <option value=\"Standard Submarine\">Standard Submarine</option>" +
            "                    <option value=\"Custom\">Custom</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >主动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control active-sonar-signature\" placeholder=\"主动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >红外线(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control infrared-signature\"  placeholder=\"红外线\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >MAD传感器(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control mad-signature\" placeholder=\"MAD传感器\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label for=\"PassiveSonar\">被动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control passive-sonar-signature\" placeholder=\"被动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >雷达(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control radar-signature\"  placeholder=\"雷达\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >视觉(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control visual-signature\"  placeholder=\"视觉\" style=\"width:35%;\">" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label >损坏：</label>" +
            "              <select class=\"form-control damage-system\" >" +
            "                <option></option>" +
            "              </select>" +
            "            </div>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "          </div>" +
            "          <div class=\"panel panel-primary sensorGroupBox\">" +
            "            <div class=\"panel-heading\">传感器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 sensor-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary weapon\">" +
            "            <div class=\"panel-heading\">武器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 weapon-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary additionalSystem\">" +
            "            <div class=\"panel-heading\">附加系统</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 other-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        </div>";

        div.innerHTML = innerHTML;
        return div;
    }

    ui_FixedWingParam() {
        var div = document.createElement("div");
        var innerHtml = "<div class=\"content\">" +
            "          <form class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label for=\"short-name\">简称:</label>" +
            "              <input type=\"input\" class=\"form-control short-name\" placeholder=\"简称\">" +
            "            </div>" +
            "          </form>" +
            "          <div class=\"panel panel-primary size myForm\">" +
            "            <div class=\"panel-heading \">大小</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group dimensions\">" +
            "                  <label >尺寸(长,宽,高)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control length\" placeholder=\"长\">" +
            "                  <input type=\"input\" class=\"form-control width\"  placeholder=\"宽\">" +
            "                  <input type=\"input\" class=\"form-control height\" placeholder=\"高\">" +
            "                </div>" +
            "                <div class=\"form-group offset\">" +
            "                  <label >偏移(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control offset-front\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control offset-right\" placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control offset-up\"    placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"SelectComboBox form-inline\">" +
            "                  <label>原点</label>" +
            "                  <select class=\"combobox form-control offsetType\">" +
            "                    <option value=\"center\">中心</option>" +
            "                    <option value=\"ground-center\">底部中点</option>" +
            "                    <option value=\"custom\">自定义</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group left-support\">" +
            "                  <label >左支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control left-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control left-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control left-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group right-support\">" +
            "                  <label >右支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control right-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control right-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control right-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group other-support\">" +
            "                  <label >其他支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control other-support-forward\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control other-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control other-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"btn-group\" role=\"group\" aria-label=\"...\">" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <div class=\"checkbox\" style=\"line-height:34px; margin-left: 15px;\">" +
            "                    <label>" +
            "                      <input type=\"checkbox\" class=\"dealWithEliminate\"> 从批处理中更新排除" +
            "                    </label>" +
            "                  </div>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <form class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label >最大解聚距离：</label>" +
            "              <input type=\"input\" class=\"form-control disaggregation-range\" placeholder=\"最大解聚距离：\">" +
            "            </div>" +
            "          </form>" +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">动作</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >动力学：</label>" +
            "                  <select class=\"form-control movement-system\">" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >质量(kg)：</label>" +
            "                  <input type=\"input\" class=\"form-control mass\" placeholder=\"质量\">" +
            "                </div> " +
            "                <div class=\"form-group\">" +
            "                  <label >最大速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control max-speed\"  placeholder=\"最大速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大高度(m):</label>" +
            "                  <input type=\"input\" class=\"form-control max-altitude\" placeholder=\"最大高度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最小航速(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control min-speed\" placeholder=\"最小航速\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >默认航速(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control ordered-speed\" placeholder=\"默认航速\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大推力加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-acceleration\"  placeholder=\"最大推力加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大角加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-lateral-acceleration\" placeholder=\"最大角加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大减速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-deceleration\" placeholder=\"最大减速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大升速(m/min)：</label>" +
            "                  <input type=\"input\" class=\"form-control max-climb-rate\" placeholder=\"最大升速\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大角速度(deg/s):</label>" +
            "                  <input type=\"input\" class=\"form-control max-yaw-rate\" placeholder=\"最大角速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大俯仰率(deg/s):</label>" +
            "                  <input type=\"input\" class=\"form-control max-pitch-rate\"  placeholder=\"最大俯仰率\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大滚转角速度(deg/s):</label>" +
            "                  <input type=\"input\" class=\"form-control max-roll-rate\" placeholder=\"最大滚转角速度\"style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-embark\"> 可装载" +
            "                  </label>" +
            "                </div>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-move-onto-embarked\"> 可移植到敌对势力上" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-be-embarked-upon\"> 可以开始" +
            "                  </label>" +
            "                </div>" +
            "                <button class=\"btn btn-default\" type=\"button\" style=\"margin-left: 20px;\">配置...</button>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"protect-from-collateral-damage\"> 保护登船实体免受附带损害" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"use-object-geometry\" > 在仿真引擎中使用详细的几何图形" +
            "                  </label>" +
            "                </div>" +
            "                <button class=\"btn btn-default\" type=\"button\">选择</button>" +
            "                <div class=\"form-group\">" +
            "                  <label >航行数据</label>" +
            "                  <input type=\"input\" class=\"form-control SaleData\"  placeholder=\"航行数据\" style=\"width:35%;\">" +
            "                  <button class=\"btn btn-default\" type=\"button\">生成</button>" +
            "                  <button class=\"btn btn-default\" type=\"button\">清除</button>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">传感信号</div>" +
            "            <div class=\"panel-body sensorSignatures\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >预定义信号：</label>" +
            "                  <select class=\"form-control PredefinedSignal\">" +
            "                    <option value=\"Standard Building\">Standard Building</option>" +
            "                    <option value=\"Standard Fixed Wing\">Standard Fixed Wing</option>" +
            "                    <option value=\"Standard Ground Vehicle\">Standard Ground Vehicle</option>" +
            "                    <option value=\"Standard Human\">Standard Human</option>" +
            "                    <option value=\"Standard Rotary Wing\">Standard Rotary Wing</option>" +
            "                    <option value=\"Standard Ship\">Standard Ship</option>" +
            "                    <option value=\"Standard Submarine\">Standard Submarine</option>" +
            "                    <option value=\"Custom\">Custom</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >主动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control active-sonar-signature\" placeholder=\"主动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >红外线(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control infrared-signature\"  placeholder=\"红外线\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >MAD传感器(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control mad-signature\" placeholder=\"MAD传感器\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label for=\"PassiveSonar\">被动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control passive-sonar-signature\" placeholder=\"被动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >雷达(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control radar-signature\"  placeholder=\"雷达\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >视觉(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control visual-signature\"  placeholder=\"视觉\" style=\"width:35%;\">" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label >损坏：</label>" +
            "              <select class=\"form-control damage-system\" >" +
            "                <option></option>" +
            "              </select>" +
            "            </div>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "          </div>" +
            "          <div class=\"panel panel-primary sensor\">" +
            "            <div class=\"panel-heading\">传感器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 sensor-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary weapon\">" +
            "            <div class=\"panel-heading\">武器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 weapon-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary additionalSystem\">" +
            "            <div class=\"panel-heading\">附加系统</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 other-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        </div>";

        div.innerHTML = innerHtml;
        return div;

    }

    ui_MissileParam() {

        var div = document.createElement("div");

        var innerHTML = "<div class=\"content\">" +
            "          <form class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label >简称:</label>" +
            "              <input type=\"input\" class=\"form-control short-name\" placeholder=\"简称\">" +
            "            </div>" +
            "          </form>" +
            "          <div class=\"panel panel-primary size myForm\">" +
            "            <div class=\"panel-heading \">大小</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group dimensions\">" +
            "                  <label >尺寸(长,宽,高)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control length\" placeholder=\"长\">" +
            "                  <input type=\"input\" class=\"form-control width\"  placeholder=\"宽\">" +
            "                  <input type=\"input\" class=\"form-control height\" placeholder=\"高\">" +
            "                </div>" +
            "                <div class=\"form-group offset\">" +
            "                  <label >偏移(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control offset-front\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control offset-right\" placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control offset-up\"    placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"btn-group\" role=\"group\" aria-label=\"...\">" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <div class=\"checkbox\" style=\"line-height:34px; margin-left: 15px;\">" +
            "                    <label>" +
            "                      <input type=\"checkbox\" class=\"dealWithEliminate\"> 从批处理中更新排除" +
            "                    </label>" +
            "                  </div>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <form class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label >最大解聚距离：</label>" +
            "              <input type=\"input\" class=\"form-control disaggregation-range\" placeholder=\"最大解聚距离：\">" +
            "            </div>" +
            "          </form>" +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">动作</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >动力学：</label>" +
            "                  <select class=\"form-control movement-system\">" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >质量(kg)：</label>" +
            "                  <input type=\"input\" class=\"form-control mass\" placeholder=\"质量\">" +
            "                </div> " +
            "                <div class=\"form-group\">" +
            "                  <label >最大速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control max-speed\"  placeholder=\"最大速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >默认航速(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control ordered-speed\" placeholder=\"默认航速\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-acceleration\"  placeholder=\"最大加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大减速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control  max-deceleration\" placeholder=\"最大减速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大射程(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control effective-range\" placeholder=\"最大射程\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大机动Gs:</label>" +
            "                  <input type=\"input\" class=\"form-control max-maneuver-gs\" placeholder=\"最大机动Gs\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >CEP半径(m):</label>" +
            "                  <input type=\"input\" class=\"form-control cep-radius\" placeholder=\"CEP半径\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >过渡角度(rad):</label>" +
            "                  <input type=\"input\" class=\"form-control transition-angle\"  placeholder=\"过渡角度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >比例导航增益：</label>" +
            "                  <input type=\"input\" class=\"form-control proportional-navigation-gain\"  placeholder=\"比例导航增益：\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"fire-and-forget\"> Fire and Forget" +
            "                  </label>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary countermeasure\">" +
            "            <div class=\"panel-heading\">对策：</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >对策类型：</label>" +
            "                  <select class=\"form-control counter-measure-type\">" +
            "                    <option value=\"CISChaff|8:2:222:2:1:0:0\">CISChaff|8:2:222:2:1:0:0</option>" +
            "                    <option value=\"CISFlare|8:2:222:2:1:1:0\">CISFlare|8:2:222:2:1:1:0</option>" +
            "                    <option value=\"USChaff|8:2:225:2:1:0:0\">USChaff|8:2:225:2:1:0:0</option>" +
            "                    <option value=\"USFlare|8:2:225:2:1:1:0\">USFlare|8:2:225:2:1:1:0</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >干扰概率：</label>" +
            "                  <input type=\"input\" class=\"form-control distraction-probability\" placeholder=\"干扰概率：\" style=\"width:55%;\">" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label >区域名称：</label>" +
            "              <input class=\"form-control range-name\" type=\"input\" placeholder=\"区域名称：\" style=\"width:55%;\"></input>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">传感信号</div>" +
            "            <div class=\"panel-body sensorSignatures\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >预定义信号：</label>" +
            "                  <select class=\"form-control PredefinedSignal\">" +
            "                    <option value=\"Standard Building\">Standard Building</option>" +
            "                    <option value=\"Standard Fixed Wing\">Standard Fixed Wing</option>" +
            "                    <option value=\"Standard Ground Vehicle\">Standard Ground Vehicle</option>" +
            "                    <option value=\"Standard Human\">Standard Human</option>" +
            "                    <option value=\"Standard Rotary Wing\">Standard Rotary Wing</option>" +
            "                    <option value=\"Standard Ship\">Standard Ship</option>" +
            "                    <option value=\"Standard Submarine\">Standard Submarine</option>" +
            "                    <option value=\"Custom\">Custom</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >主动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control active-sonar-signature\" placeholder=\"主动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >红外线(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control infrared-signature\"  placeholder=\"红外线\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >MAD传感器(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control mad-signature\" placeholder=\"MAD传感器\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label for=\"PassiveSonar\">被动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control passive-sonar-signature\" placeholder=\"被动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >雷达(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control radar-signature\"  placeholder=\"雷达\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >视觉(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control visual-signature\"  placeholder=\"视觉\" style=\"width:35%;\">" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label>损坏：</label>" +
            "              <select class=\"form-control damage-system\" >" +
            "                <option></option>" +
            "              </select>" +
            "            </div>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "          </div>" +
            "          <div class=\"panel panel-primary sensor\">" +
            "            <div class=\"panel-heading\">传感器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 damage-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        </div>";

        div.innerHTML = innerHTML;
        return div;

    }

    ui_RotaryWingParam() {

        var div = document.createElement("div");

        var innerHTML = "<div class=\"content\">" +
            "          <form class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label >简称:</label>" +
            "              <input type=\"input\" class=\"form-control short-name\" placeholder=\"简称\">" +
            "            </div>" +
            "          </form>" +
            "          <div class=\"panel panel-primary size myForm\">" +
            "            <div class=\"panel-heading \">大小</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group dimensions\">" +
            "                  <label >尺寸(长,宽,高)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control length\" placeholder=\"长\">" +
            "                  <input type=\"input\" class=\"form-control width\"  placeholder=\"宽\">" +
            "                  <input type=\"input\" class=\"form-control height\" placeholder=\"高\">" +
            "                </div>" +
            "                <div class=\"form-group offset\">" +
            "                  <label >偏移(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control offset-front\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control offset-right\" placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control offset-up\"    placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"SelectComboBox form-inline\">" +
            "                  <label>原点</label>" +
            "                  <select class=\"combobox form-control offsetType\">" +
            "                    <option value=\"center\">中心</option>" +
            "                    <option value=\"ground-center\">底部中点</option>" +
            "                    <option value=\"custom\">自定义</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group left-support\">" +
            "                  <label >左支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control left-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control left-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control left-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group right-support\">" +
            "                  <label >右支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control right-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control right-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control right-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group other-support\">" +
            "                  <label >其他支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control other-support-forward\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control other-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control other-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"btn-group\" role=\"group\" aria-label=\"...\">" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <div class=\"checkbox\" style=\"line-height:34px; margin-left: 15px;\">" +
            "                    <label>" +
            "                      <input type=\"checkbox\" class=\"dealWithEliminate\"> 从批处理中更新排除" +
            "                    </label>" +
            "                  </div>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">动作</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >动力学：</label>" +
            "                  <select class=\"form-control movement-system\">" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >质量(kg)：</label>" +
            "                  <input type=\"input\" class=\"form-control mass\" placeholder=\"质量\">" +
            "                </div> " +
            "                <div class=\"form-group\">" +
            "                  <label >最大速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control max-speed\"  placeholder=\"最大速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >默认速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control ordered-speed\" placeholder=\"默认速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-acceleration\" placeholder=\"最大加速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大减速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-deceleration\" placeholder=\"最大减速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大爬升率(m/min):</label>" +
            "                  <input type=\"input\" class=\"form-control max-climb-rate\"  placeholder=\"最大爬升率\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大偏航率(deg/s):</label>" +
            "                  <input type=\"input\" class=\"form-control max-yaw-rate\" placeholder=\"最大偏航率\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大偏航加速度(deg/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-yaw-acceleration\" placeholder=\"最大偏航加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大俯仰率(deg/s)：</label>" +
            "                  <input type=\"input\" class=\"form-control max-pitch-rate\" placeholder=\"最大俯仰率\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大俯仰加速度(deg/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-pitch-acceleration\" placeholder=\"最大俯仰加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大滚动率(deg/s):</label>" +
            "                  <input type=\"input\" class=\"form-control max-roll-rate\"  placeholder=\"最大滚动率\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >最大滚动加速度(deg/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-roll-acceleration\" placeholder=\"最大滚动加速度\"style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >零总升力(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control zero-collective-lift-acceleration\" placeholder=\"零总升力\"style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >全总升力(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control full-collective-lift-acceleration\" placeholder=\"全总升力\"style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >阻力系数(n/a):</label>" +
            "                  <input type=\"input\" class=\"form-control drag-coefficient\" placeholder=\"阻力系数\"style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >拖动参考区域(m^2):</label>" +
            "                  <input type=\"input\" class=\"form-control drag-reference-area\" placeholder=\"拖动参考区域\"style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-embark\"> 可乘坐" +
            "                  </label>" +
            "                </div>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-move-onto-embarked\"> 可移植到敌对势力上" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-be-embarked-upon\"> 可以开始" +
            "                  </label>" +
            "                </div>" +
            "                <button class=\"btn btn-default\" type=\"button\" style=\"margin-left: 20px;\">配置...</button>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"protect-from-collateral-damage\"> 保护登船实体免受附带损害" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"use-object-geometry\" > 在仿真引擎中使用详细的几何图形" +
            "                  </label>" +
            "                </div>" +
            "                <button class=\"btn btn-default\" type=\"button\">选择</button>" +
            "                <div class=\"form-group\">" +
            "                  <label >航行数据</label>" +
            "                  <input type=\"input\" class=\"form-control SaleData\"  placeholder=\"航行数据\" style=\"width:35%;\">" +
            "                  <button class=\"btn btn-default\" type=\"button\">生成</button>" +
            "                  <button class=\"btn btn-default\" type=\"button\">清除</button>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">传感信号</div>" +
            "            <div class=\"panel-body sensorSignatures\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >预定义信号：</label>" +
            "                  <select class=\"form-control PredefinedSignal\">" +
            "                    <option value=\"Standard Building\">Standard Building</option>" +
            "                    <option value=\"Standard Fixed Wing\">Standard Fixed Wing</option>" +
            "                    <option value=\"Standard Ground Vehicle\">Standard Ground Vehicle</option>" +
            "                    <option value=\"Standard Human\">Standard Human</option>" +
            "                    <option value=\"Standard Rotary Wing\">Standard Rotary Wing</option>" +
            "                    <option value=\"Standard Ship\">Standard Ship</option>" +
            "                    <option value=\"Standard Submarine\">Standard Submarine</option>" +
            "                    <option value=\"Custom\">Custom</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >主动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control active-sonar-signature\" placeholder=\"主动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >红外线(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control infrared-signature\"  placeholder=\"红外线\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >MAD传感器(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control mad-signature\" placeholder=\"MAD传感器\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label for=\"PassiveSonar\">被动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control passive-sonar-signature\" placeholder=\"被动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >雷达(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control radar-signature\"  placeholder=\"雷达\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >视觉(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control visual-signature\"  placeholder=\"视觉\" style=\"width:35%;\">" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label >损坏：</label>" +
            "              <select class=\"form-control damage-system\" >" +
            "              </select>" +
            "            </div>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "          </div>" +
            "          <div class=\"panel panel-primary sensor\">" +
            "            <div class=\"panel-heading\">传感器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 sensor-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary weapon\">" +
            "            <div class=\"panel-heading\">武器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 weapon-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary additionalSystem\">" +
            "            <div class=\"panel-heading\">附加系统</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 other-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        </div>";

        div.innerHTML = innerHTML;
        return div;

    }

    ui_SubsurfaceParam() {

        var div = document.createElement("div");

        var innerHTML = "<div class=\"content\">" +
            "          <form class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label>简称:</label>" +
            "              <input type=\"input\" class=\"form-control short-name\" placeholder=\"简称\">" +
            "            </div>" +
            "          </form>" +
            "        " +
            "          <div class=\"panel panel-primary size myForm\">" +
            "            <div class=\"panel-heading \">大小</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group dimensions\"> " +
            "                  <label>尺寸(长,宽,高)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control length\" placeholder=\"长\">" +
            "                  <input type=\"input\" class=\"form-control width\" placeholder=\"宽\">" +
            "                  <input type=\"input\" class=\"form-control height\" placeholder=\"高\">" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group offset\">" +
            "                  <label>偏移(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control offset-front\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control offset-right\" placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control offset-up\" placeholder=\"上\">" +
            "                </div>" +
            "        " +
            "                <div class=\"SelectComboBox form-inline\">" +
            "                  <label>原点</label>" +
            "                  <select class=\"combobox form-control offsetType\">" +
            "                    <option value=\"center\">中心</option>" +
            "                    <option value=\"ground-center\">底部中点</option>" +
            "                    <option value=\"custom\">自定义</option>" +
            "                  </select>" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group left-support\">" +
            "                  <label >左支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control left-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control left-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control left-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group right-support\">" +
            "                  <label >右支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control right-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control right-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control right-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group other-support\">" +
            "                  <label >其他支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control other-support-forward\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control other-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control other-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "        " +
            "                <div class=\"btn-group\" role=\"group\" aria-label=\"...\">" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <div class=\"checkbox\" style=\"line-height:34px; margin-left: 15px;\">" +
            "                    <label>" +
            "                      <input type=\"checkbox\" class=\"dealWithEliminate\"> 从批处理中更新排除" +
            "                    </label>" +
            "                  </div>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        " +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">动作</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label>动力学：</label>" +
            "                  <select class=\"form-control movement-system\">" +
            "                  </select>" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>质量(kg)：</label>" +
            "                  <input type=\"input\" class=\"form-control mass\" placeholder=\"质量\">" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>最大速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control max-speed\" placeholder=\"最大速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label>默认速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control ordered-speed\" placeholder=\"默认航速\" style=\"width:55%;\">" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>最大加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-acceleration\" placeholder=\"最大推力加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "           " +
            "                <div class=\"form-group\">" +
            "                  <label>最大减速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-deceleration\" placeholder=\"最大减速度\" style=\"width:35%;\">" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>最大深度(m):</label>" +
            "                  <input type=\"input\" class=\"form-control max-depth\" placeholder=\"最大深度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label>最大侧加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-lateral-acceleration\" placeholder=\"最大侧加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label>最大角速度(deg/s):</label>" +
            "                  <input type=\"input\" class=\"form-control max-slope\" placeholder=\"最大角速度\" style=\"width:35%;\">" +
            "                </div>" +
            "        " +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-embark\"> 可乘坐" +
            "                  </label>" +
            "                </div>" +
            "        " +
            "        " +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-move-onto-embarked\"> 可移植到敌对势力上" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-be-embarked-upon\"> 可以开始" +
            "                  </label>" +
            "                </div>" +
            "                <button class=\"btn btn-default\" type=\"button\"  style=\"margin-left: 20px;\">配置...</button>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"protect-from-collateral-damage\"> 保护登船实体免受附带损害" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "        " +
            "                <button class=\"btn btn-default\" type=\"button\">选择</button>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>航行数据</label>" +
            "                  <input type=\"input\" class=\"form-control SaleData\" placeholder=\"航行数据\" style=\"width:35%;\">" +
            "                  <button class=\"btn btn-default\" type=\"button\">生成</button>" +
            "                  <button class=\"btn btn-default\" type=\"button\">清除</button>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        " +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">传感信号</div>" +
            "            <div class=\"panel-body sensorSignatures\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >预定义信号：</label>" +
            "                  <select class=\"form-control PredefinedSignal\">" +
            "                    <option value=\"Standard Building\">Standard Building</option>" +
            "                    <option value=\"Standard Fixed Wing\">Standard Fixed Wing</option>" +
            "                    <option value=\"Standard Ground Vehicle\">Standard Ground Vehicle</option>" +
            "                    <option value=\"Standard Human\">Standard Human</option>" +
            "                    <option value=\"Standard Rotary Wing\">Standard Rotary Wing</option>" +
            "                    <option value=\"Standard Ship\">Standard Ship</option>" +
            "                    <option value=\"Standard Submarine\">Standard Submarine</option>" +
            "                    <option value=\"Custom\">Custom</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >主动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control active-sonar-signature\" placeholder=\"主动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >红外线(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control infrared-signature\"  placeholder=\"红外线\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >MAD传感器(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control mad-signature\" placeholder=\"MAD传感器\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label for=\"PassiveSonar\">被动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control passive-sonar-signature\" placeholder=\"被动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >雷达(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control radar-signature\"  placeholder=\"雷达\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >视觉(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control visual-signature\"  placeholder=\"视觉\" style=\"width:35%;\">" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        " +
            "          <div class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label>损坏：</label>" +
            "              <select class=\"form-control damage-system\">" +
            "              </select>" +
            "            </div>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "          </div>" +
            "        " +
            "          <div class=\"panel panel-primary sensor\">" +
            "            <div class=\"panel-heading\">传感器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 sensor-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        " +
            "          <div class=\"panel panel-primary weapon\">" +
            "            <div class=\"panel-heading\">武器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 weapon-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        " +
            "          <div class=\"panel panel-primary additionalSystem\">" +
            "            <div class=\"panel-heading\">附加系统</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 other-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        </div>";

        div.innerHTML = innerHTML;
        return div;

    }
    ui_SurfaceShipParam() {

        var div = document.createElement("div");

        var innerHTML = "<div class=\"content\">" +
            "          <form class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label >简称:</label>" +
            "              <input type=\"input\" class=\"form-control short-name\" placeholder=\"简称\">" +
            "            </div>" +
            "          </form>" +
            "        " +
            "          <div class=\"panel panel-primary size myForm\">" +
            "            <div class=\"panel-heading \">大小</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group dimensions\">" +
            "                  <label>尺寸(长,宽,高)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control length\" placeholder=\"长\">" +
            "                  <input type=\"input\" class=\"form-control width\" placeholder=\"宽\">" +
            "                  <input type=\"input\" class=\"form-control height\" placeholder=\"高\">" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group offset\">" +
            "                  <label>偏移(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control offset-front\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control offset-right\" placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control offset-up\" placeholder=\"上\">" +
            "                </div>" +
            "        " +
            "                <div class=\"SelectComboBox form-inline\">" +
            "                  <label>原点</label>" +
            "                  <select class=\"combobox form-control offsetType\">" +
            "                    <option value=\"center\">中心</option>" +
            "                    <option value=\"ground-center\">底部中点</option>" +
            "                    <option value=\"custom\">自定义</option>" +
            "                  </select>" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group left-support\">" +
            "                  <label >左支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control left-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control left-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control left-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group right-support\">" +
            "                  <label >右支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control right-support-forward\"  placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control right-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control right-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "                <div class=\"form-group other-support\">" +
            "                  <label >其他支撑(前,右,上)(m):</label>" +
            "                  <input type=\"input\" class=\"form-control other-support-forward\" placeholder=\"前\">" +
            "                  <input type=\"input\" class=\"form-control other-support-right\"  placeholder=\"右\">" +
            "                  <input type=\"input\" class=\"form-control other-support-down\" placeholder=\"上\">" +
            "                </div>" +
            "        " +
            "                <div class=\"btn-group\" role=\"group\" aria-label=\"...\">" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <button type=\"button\" class=\"btn btn-default\">...</button>" +
            "                  <div class=\"checkbox\" style=\"line-height:34px; margin-left: 15px;\">" +
            "                    <label>" +
            "                      <input type=\"checkbox\" class=\"dealWithEliminate\"> 从批处理中更新排除" +
            "                    </label>" +
            "                  </div>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">动作</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label>动力学：</label>" +
            "                  <select class=\"form-control movement-system\">" +
            "                  </select>" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>质量(kg)：</label>" +
            "                  <input type=\"input\" class=\"form-control mass\" placeholder=\"质量\">" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>最大速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control max-speed\" placeholder=\"最大速度\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label>默认速度(km/h):</label>" +
            "                  <input type=\"input\" class=\"form-control ordered-speed\" placeholder=\"默认航速\" style=\"width:55%;\">" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>最大倒速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-reverse-speed\" placeholder=\"最大倒速度\" style=\"width:35%;\">" +
            "                </div>" +
            "           " +
            "                <div class=\"form-group\">" +
            "                  <label>最大加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-acceleration\" placeholder=\"最大加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>最大减速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-deceleration\" placeholder=\"最大减速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label>最大侧加速度(m/s^2):</label>" +
            "                  <input type=\"input\" class=\"form-control max-lateral-acceleration:\" placeholder=\"最大侧加速度\" style=\"width:35%;\">" +
            "                </div>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-pivot\"> 可转动" +
            "                  </label>" +
            "                </div>" +
            "        " +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-embark\"> 可乘坐" +
            "                  </label>" +
            "                </div>" +
            "        " +
            "        " +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-move-onto-embarked\"> 可移植到敌对势力上" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"can-be-embarked-upon\"> 可以开始" +
            "                  </label>" +
            "                </div>" +
            "                <button class=\"btn btn-default\" type=\"button\" style=\"margin-left: 20px;\">配置...</button>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"protect-from-collateral-damage\"> 保护登船实体免受附带损害" +
            "                  </label>" +
            "                </div>" +
            "                <br>" +
            "                <div class=\"checkbox\" style=\"line-height:34px;\">" +
            "                  <label>" +
            "                    <input type=\"checkbox\" class=\"use-object-geometry\"> 在仿真引擎中使用详细的几何图形" +
            "                  </label>" +
            "                </div>" +
            "        " +
            "                <button class=\"btn btn-default\" type=\"button\">选择</button>" +
            "        " +
            "                <div class=\"form-group\">" +
            "                  <label>航行数据</label>" +
            "                  <input type=\"input\" class=\"form-control SaleData\" placeholder=\"航行数据\" style=\"width:35%;\">" +
            "                  <button class=\"btn btn-default\" type=\"button\">生成</button>" +
            "                  <button class=\"btn btn-default\" type=\"button\">清除</button>" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        " +
            "          <div class=\"panel panel-primary action\">" +
            "            <div class=\"panel-heading\">传感信号</div>" +
            "            <div class=\"panel-body sensorSignatures\">" +
            "              <form class=\"form-inline margin-bottom-10\">" +
            "                <div class=\"form-group\">" +
            "                  <label >预定义信号：</label>" +
            "                  <select class=\"form-control PredefinedSignal\">" +
            "                    <option value=\"Standard Building\">Standard Building</option>" +
            "                    <option value=\"Standard Fixed Wing\">Standard Fixed Wing</option>" +
            "                    <option value=\"Standard Ground Vehicle\">Standard Ground Vehicle</option>" +
            "                    <option value=\"Standard Human\">Standard Human</option>" +
            "                    <option value=\"Standard Rotary Wing\">Standard Rotary Wing</option>" +
            "                    <option value=\"Standard Ship\">Standard Ship</option>" +
            "                    <option value=\"Standard Submarine\">Standard Submarine</option>" +
            "                    <option value=\"Custom\">Custom</option>" +
            "                  </select>" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >主动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control active-sonar-signature\" placeholder=\"主动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >红外线(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control infrared-signature\"  placeholder=\"红外线\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >MAD传感器(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control mad-signature\" placeholder=\"MAD传感器\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label for=\"PassiveSonar\">被动声纳(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control passive-sonar-signature\" placeholder=\"被动声纳\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >雷达(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control radar-signature\"  placeholder=\"雷达\" style=\"width:55%;\">" +
            "                </div>" +
            "                <div class=\"form-group\">" +
            "                  <label >视觉(km)：</label>" +
            "                  <input type=\"input\" class=\"form-control visual-signature\"  placeholder=\"视觉\" style=\"width:35%;\">" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        " +
            "          <div class=\"form-inline margin-bottom-10\">" +
            "            <div class=\"form-group\">" +
            "              <label>损坏：</label>" +
            "              <select class=\"form-control damage-system\">" +
            "                <option></option>" +
            "              </select>" +
            "            </div>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "            <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "          </div>" +
            "        " +
            "          <div class=\"panel panel-primary sensor\">" +
            "            <div class=\"panel-heading\">传感器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 sensor-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        " +
            "          <div class=\"panel panel-primary weapon\">" +
            "            <div class=\"panel-heading\">武器</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 weapon-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        " +
            "          <div class=\"panel panel-primary additionalSystem\">" +
            "            <div class=\"panel-heading\">附加系统</div>" +
            "            <div class=\"panel-body\">" +
            "              <form class=\"form-inline\">" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <button class=\"btn btn-default\" type=\"button\">...</button>" +
            "                <div class=\"list-group margin-top-10 other-system\">" +
            "                  <!-- <a href=\"javascript:;\" class=\"list-group-item\">Dapibus ac facilisis in</a> -->" +
            "                </div>" +
            "              </form>" +
            "            </div>" +
            "          </div>" +
            "        </div>";

        div.innerHTML = innerHTML;
        return div;
    }

    DtRwOffsetVector() {
        let div = document.createElement("div");
        let innerHTML = "<label style=\"display:block; text-align:left;\" class=\"title\"></label>" +
            "<div class=\"form-group\"> <label>前(m)：</label> <input type=\"input\" class=\"form-control \" placeholder=\"前\" style=\"width:60%;display:inline-block;\"> </div>" +
            "<div class=\"form-group\"> <label>右(m)：</label> <input type=\"input\" class=\"form-control \" placeholder=\"右\" style=\"width:60%;display:inline-block;\"> </div>" +
            "<div class=\"form-group\"> <label>上(m)：</label> <input type=\"input\" class=\"form-control \" placeholder=\"上\" style=\"width:60%;display:inline-block;\"> </div>";
        div.innerHTML = innerHTML;
        return div;
    }

    DtRwReal() {
        let div = document.createElement("div");
        let innerHTML = "<label style=\"display:block; text-align:left;\" class=\"title\"></label>" +
            "<div class=\"form-group\"> <label>测试：</label> <input type=\"input\" class=\"form-control \" placeholder=\"测试\" style=\"width:60%;display:inline-block;\"> </div>";
        div.innerHTML = innerHTML;
        return div;

    }

    DtRwTaitBryan() {
        let div = document.createElement("div");
        let innerHTML = "<label style=\"display:block; text-align:left;\" class=\"title\"></label>" +
            "<div class=\"form-group\"> <label>偏航角(deg)：</label> <input type=\"input\" class=\"form-control \" placeholder=\"偏航角\" style=\"width:60%;display:inline-block;\"> </div>" +
            "<div class=\"form-group\"> <label>旋转角(deg)：</label> <input type=\"input\" class=\"form-control \" placeholder=\"旋转角\" style=\"width:60%;display:inline-block;\"> </div>" +
            "<div class=\"form-group\"> <label>倾斜角(deg)：</label> <input type=\"input\" class=\"form-control \" placeholder=\"倾斜角\" style=\"width:60%;display:inline-block;\"> </div>";
        div.innerHTML = innerHTML;
        return div;
    }

    SensitivityModifier() {
        let div = document.createElement("div");
        let innerHTML = " <input type=\"text\" class=\"js-range-slider\" name=\"my_range\" value=\"\" />" +
            "    <table class=\"table table-striped\" style=\"padding:0 20px;\">" +
            "      <thead>" +
            "        <tr></tr>" +
            "      </thead>" +
            "      <tbody>" +
            "      </tbody>" +
            "    </table>";
        div.innerHTML = innerHTML;
        return div;
    }

    MyCheckBox() {
        let div = document.createElement("div");
        let innerHTML = "<div class=\"checkbox\">" +
            "                    <label>" +
            "                      <input type=\"checkbox\"> <span>中立</span>" +
            "                    </label>" +
            "                  </div>";
        div.innerHTML = innerHTML;
        return div;
    }

    createHTML(id) {
        switch (id) {
            case "Ground_Vehicle":
                return this.ui_GroundVehicleParam();
                break;

            case "Fixed_Wing":
                return this.ui_FixedWingParam();
                break;

            case "Missile":
                return this.ui_MissileParam();
                break;

            case "Rotary_Wing":
                return this.ui_RotaryWingParam();
                break;

            case "Subsurface":
                return this.ui_SubsurfaceParam();
                break;

            case "Surface_Ship":
                return this.ui_SurfaceShipParam();
                break;
        }
    }

}

module.exports = ui;
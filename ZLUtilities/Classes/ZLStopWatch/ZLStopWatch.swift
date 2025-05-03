//
//  ZLStopWatch.swift
//  ZLUtilities
//
//  Created by 朱猛 on 2025/5/3.
//

import Foundation
import UIKit

/// 后台挂起，仍然及时的秒表
public class ZLStopWatch: NSObject {

    @objc dynamic private(set) var isSuspend: Bool = true  /// 定时器是否挂起

    @objc dynamic private var timer: DispatchSourceTimer?

    @objc dynamic private let queue: DispatchQueue

    @objc dynamic private var timeStamp: Double = 0

    dynamic private var eventHandler: ((Int) -> Void)?

    deinit {
        stopWatch_deinit()
    }

    @objc dynamic func stopWatch_deinit() {
        cancel()
    }

    public init(deadline: DispatchTime,
                repeating interval: DispatchTimeInterval = .never,
                leeway: DispatchTimeInterval = .nanoseconds(0),
                queue: DispatchQueue = .main,
                eventHandler: ((Int) -> Void)? = nil) {
        self.timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.main)
        self.queue = queue
        self.eventHandler = eventHandler
        super.init()
        self.setup(deadline: deadline, repeating: interval, leeway: leeway)
    }

    private func setup(deadline: DispatchTime,
                       repeating interval: DispatchTimeInterval,
                       leeway: DispatchTimeInterval) {

        timer?.schedule(deadline: deadline, repeating: interval, leeway: leeway)
        timer?.setEventHandler { [weak self] in
            guard let self else { return }
            self.dealWithEventHandler()
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    @objc dynamic func dealWithEventHandler() {
        let currentTimeStamp = getCurrentTimeStamp()
        let elapsedTime = Int(round(currentTimeStamp - self.timeStamp))

        self.timeStamp = currentTimeStamp

        if queue.label == DispatchQueue.main.label {
            self.eventHandler?(elapsedTime)
        } else {
            queue.async { [weak self] in
                self?.eventHandler?(elapsedTime)
            }
        }


    }

    @objc dynamic private func applicationWillResignActive() {
        guard !isCancelled else { return }
        suspend()
    }

    @objc dynamic private func applicationDidBecomeActive() {
        guard  !isCancelled else { return }
        resume()
    }

    @objc dynamic private func resume() {
        if !isCancelled, isSuspend {
            timer?.resume()
            isSuspend = false
        }
    }


    @objc dynamic public func suspend() {
        if !isCancelled, !isSuspend  {
            timer?.suspend()
            isSuspend = true
        }
    }


    /// 获取当前时间戳
    /// 以s为单位
    /// 相对时间：系统启动后经过的时间
    /// 休眠/锁定也会计时
    @objc dynamic private func getCurrentTimeStamp() -> Double {
        let curr = mach_continuous_time()
        var info = mach_timebase_info(numer: 1, denom: 1)
        mach_timebase_info(&info)
        return Double(curr) * Double(info.numer) / Double(info.denom) / 1e9
    }
}


public extension ZLStopWatch {

    @objc dynamic func start() {
        timeStamp = getCurrentTimeStamp()
        resume()
    }

    /**
     DispatchSourceTimer cancel注意点：
        1. 必须在 resume 之后才能够cancel， 否则会crash
        2. cancel只能执行一次，多次cancel，会crash
        3. cancel后，timer 应立即赋值为nil， 避免后面再次访问导致crash
     */
    @objc dynamic func cancel() {
        if !isCancelled {
            self.resume()    /// 避免suspend状态cancel导致的crash
            self.timer?.cancel()
            self.timer = nil           /// cancel 之后立即置空释放timer；避免可能的crash问题
            NotificationCenter.default.removeObserver(self)
        }
    }

    @objc dynamic var isCancelled: Bool {
        if let timer, !timer.isCancelled {
            return false
        } else {
            return true
        }
    }
}

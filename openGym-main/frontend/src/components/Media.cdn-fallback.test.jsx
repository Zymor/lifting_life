// @vitest-environment happy-dom
import React, { act } from 'react'
import { createRoot } from 'react-dom/client'
import { afterEach, describe, expect, it, vi } from 'vitest'

globalThis.IS_REACT_ACT_ENVIRONMENT = true

vi.mock('../store/useStore.js', () => ({ useStore: () => null }))
const { default: Media, Thumb, toCdnUrl } = await import('./Media.jsx')

const mounted = []
function mount(el) {
  const host = document.createElement('div')
  document.body.appendChild(host)
  const root = createRoot(host)
  mounted.push({ root, host })
  act(() => root.render(el))
  return { host, root }
}
afterEach(() => { act(() => { mounted.splice(0).forEach(({ root, host }) => { root.unmount(); host.remove() }) }) })

describe('Media and Thumb CDN fallback', () => {
  it('toCdnUrl converts exercise-media path to upstream CDN URL', () => {
    expect(toCdnUrl('exercise-media/still/5984.webp')).toBe('https://opengym-bc111a.gitlab.io/exercise-media/still/5984.webp')
    expect(toCdnUrl('/exercise-media/clip/5984.mp4')).toBe('https://opengym-bc111a.gitlab.io/exercise-media/clip/5984.mp4')
    expect(toCdnUrl('https://example.com/test.webp')).toBe('https://example.com/test.webp')
  })

  it('BuiltinThumb switches to CDN URL on first local error for catalogue exercise', () => {
    const ex = { id: '5984', img: '5984.webp' }
    const { host } = mount(<Thumb ex={ex} />)
    const img = host.querySelector('img.thumb')
    expect(img.getAttribute('src')).toBe('exercise-media/still/5984.webp')
    
    // Simulate local 404
    act(() => { img.dispatchEvent(new Event('error')) })
    
    // Should have switched to CDN
    const cdnImg = host.querySelector('img.thumb')
    expect(cdnImg).toBeTruthy()
    expect(cdnImg.getAttribute('src')).toBe('https://opengym-bc111a.gitlab.io/exercise-media/still/5984.webp')
  })

  it('BuiltinMedia switches to CDN URL on first local error for catalogue exercise', () => {
    const ex = { id: '5984', img: '5984.webp', gif: '5984.mp4' }
    const { host } = mount(<Media ex={ex} />)
    const video = host.querySelector('video')
    expect(video).toBeTruthy()
    expect(video.getAttribute('src')).toBe('exercise-media/clip/5984.mp4')
    
    // Simulate local 404 on video
    act(() => { video.dispatchEvent(new Event('error')) })
    
    // Video should now point to CDN
    const cdnVideo = host.querySelector('video')
    expect(cdnVideo).toBeTruthy()
    expect(cdnVideo.getAttribute('src')).toBe('https://opengym-bc111a.gitlab.io/exercise-media/clip/5984.mp4')
  })
})

